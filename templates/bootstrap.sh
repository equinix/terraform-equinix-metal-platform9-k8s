#!/bin/bash -v

##### START PACKET SPECIFIC #####
swapoff -a
sed -i '/swap/d' /etc/fstab

myhostname=`hostname`
sed -i "s/127.0.0.1\tlocalhost\t$myhostname/127.0.0.1\t$myhostname\tlocalhost/g" /etc/hosts
hostnamectl set-hostname $myhostname

mkdir /etc/pf9
host_id=`curl https://metadata.platformequinix.com/2009-04-04/meta-data/instance-id`
echo "[hostagent]" > /etc/pf9/host_id.conf 
echo "host_id = $host_id" >> /etc/pf9/host_id.conf 
sleep 60
##### END PACKET SPECIFIC #####

YUM_CONF="/etc/yum.conf"
APT_CONF="/etc/apt/apt.conf"

if [[ -n "${http_proxy}" ]]; then
    export http_proxy="${http_proxy}"
    export https_proxy="${http_proxy}"
    export HTTP_PROXY="${http_proxy}"
    export HTTPS_PROXY="${http_proxy}"
fi

# Since networking may still be initializing at boot time,
# use retry on networking-related commands
function retry {
    local num_intervals=10
    local interval=30
    for ((i=1; i<=num_intervals; i++)); do
        if "$@"; then
            return 0
        fi
        sleep $interval
    done
    "$@"
}

function get_token {
    echo "Authenticating with DU: ${du_fqdn}"
    user=${keystone_user}
    password=${keystone_password}
    keystone_url="https://${du_fqdn}/keystone/v3/auth/tokens?nocatalog"
    keystone_auth=`retry curl --silent --show-error -i -H "Content-Type: application/json" -d '
    { "auth": {
        "identity": {
        "methods": ["password"],
            "password": {
                "user": {
                    "name": "'$user'",
                    "domain": { "id": "default" },
                    "password": "'$password'"
                }
            }
        }
    }}'  $keystone_url | grep -i ^X-Subject-Token: | cut -f2 -d':' | tr -d '\r' | tr -d ' '`
    export os_token=$keystone_auth
}

function get_host_os {
    host_os_release=`cat /etc/os-release | grep "NAME="`
    if [[ $host_os_release == *"CentOS"* ]]
    then
        host_os="redhat"
    elif [[ $host_os_release == *"Ubuntu"* ]]
    then
        host_os="debian"
    fi
    export host_os=$host_os
}

function set_yum_proxy {
    if grep -q "^proxy=" $YUM_CONF; then
        sed -i "s/^proxy=.*/proxy=${http_proxy}/" $YUM_CONF
    else
        echo "proxy=${http_proxy}" >> $YUM_CONF
    fi
}

function set_apt_proxy {
    if grep -q "^Acquire::http::Proxy" $APT_CONF; then
        sed -i "s/^Acquire::http::Proxy.*/Acquire::http::Proxy \"${http_proxy}\";/" $APT_CONF
     else
        echo "Acquire::http::Proxy \"${http_proxy}\";" >> $APT_CONF
    fi
}

function install_host_agent {
    local proxy_opts="--no-proxy"
    if [[ -n "${http_proxy}" ]]; then
        echo "Setting up proxy with: ${http_proxy}"
        proxy_opts="--proxy=${http_proxy}"
        if [[ $host_os == "redhat" ]]; then
            set_yum_proxy
        else
            set_apt_proxy
        fi
    fi
    if [[ "${hostagent_installer_type}" = "legacy" ]]; then
        echo "downloading legacy hostagent installer"
        hostagent_installer="https://${du_fqdn}/private/platform9-install-$host_os.sh"
        retry curl --silent --show-error -O -H "X-Auth-Token: $os_token" $hostagent_installer
        extra_opts="${hostagent_install_options}"
    else
        echo "downloading generic ('certless') hostagent installer"
        hostagent_installer="https://${du_fqdn}/clarity/platform9-install-$host_os.sh"
        retry curl --silent --show-error -O $hostagent_installer
        extra_opts="--no-project --controller=${du_fqdn} --username=${keystone_user} --password=${keystone_password} ${hostagent_install_options}"
    fi

    if [[ "$host_os" = "debian" ]]; then
        # IAAS-8054 Update apt-get package metadata
        # since it may be out of date
        retry apt-get update
    fi

    chmod +x ./platform9-install-$host_os.sh
    if ./platform9-install-$host_os.sh "$proxy_opts" --skip-os-check --ntpd $extra_opts ; then
        echo hostagent installation succeeded
    else
        echo hostagent installation failed
        if [ -n "${hostagent_install_failure_webhook}" ] ; then
            msg="installation of hostagent from DU ${du_fqdn} for cluster ${cluster_uuid} failed on $(hostname)"
            curl -d "{\"text\":\"$msg\"}" "${hostagent_install_failure_webhook}"
        fi
    fi
}

function generate_qbert_metadata {
    mkdir -p /opt/pf9/hostagent/extensions
    echo '#!/bin/bash' > /opt/pf9/hostagent/extensions/fetch_qbert_metadata
    ext_data='{"cluster": "${cluster_uuid}", "isMaster": ${is_master}, "pool": "${node_pool_uuid}"}'
    echo "echo '$ext_data'" >> /opt/pf9/hostagent/extensions/fetch_qbert_metadata
    chmod +x /opt/pf9/hostagent/extensions/fetch_qbert_metadata

    echo '#!/bin/bash' > /opt/pf9/hostagent/extensions/fetch_node_metadata
    ext_data='{"isSpotInstance": ${is_spot_instance}}'
    echo "echo '$ext_data'" >> /opt/pf9/hostagent/extensions/fetch_node_metadata
    chmod +x /opt/pf9/hostagent/extensions/fetch_node_metadata
}

# Creates a file system on a block device and persistently mounts it
# Argument 1: block device (e.g. /dev/xvdb)
# Argument 2: mount (e.g. /var/lib/docker/aufs/)
function create_persistent_mount_from_block_device()
{
    local block_dev="$1"
    local mount="$2"

    local block_dev_uuid
    block_dev_uuid="$(blkid "$block_dev" -s UUID -o value)"
    local fs_type=ext4

    # Make file system
    mkfs -t "$fs_type" "$block_dev"

    # Mount file system
    mkdir -p "$mount"
    mount -t "$fs_type" "$block_dev" "$mount"

    # Ensure file system is mounted on boot
    cp /etc/fstab /etc/fstab.orig
    echo >> /etc/fstab "UUID=$block_dev_uuid $mount $fs_type nofail,nobootwait 0 0"
}

# Creates an LVM thin pool from a block device
# Argument 1: block device (e.g. /dev/xvdb)
# Argument 2: volume group name (e.g. docker)
# NOTE: There is a set of rules that determine valid volume group names.
# This function does not validate the name. See the lvm manpage for details.
function create_thinpool_from_block_device()
{
    local block_dev="$1"
    local vg_name="$2"

    # Suppress benign warnings
    export LVM_SUPPRESS_FD_WARNINGS=1

    # Install pre-reqs
    retry yum -y update
    retry yum -y install device-mapper-persistent-data lvm2

    # Create physical volume
    pvcreate "$block_dev"

    # Create volume group
    vgcreate "$vg_name" "$block_dev"

    # Wait for volume group to be created
    retry vgs $vg_name

    # Create logical volumes (one for data, another for metadata)
    lvcreate --wipesignatures y -n thinpool "$vg_name"  -l 95%VG
    lvcreate --wipesignatures y -n thinpoolmeta "$vg_name" -l 1%VG

    # Convert data volume to a thin volume, using metadata volume for thin volume metadata
    lvconvert -y --zero n -c 512K --thinpool "$vg_name/thinpool" --poolmetadata "$vg_name/thinpoolmeta"

    # Ensure both volumes are extended as necessary
    # - Create a profile
    cat > "/etc/lvm/profile/$vg_name-thinpool.profile" <<EOF
activation {
  thin_pool_autoextend_threshold=80
  thin_pool_autoextend_percent=20
}
EOF
    # - Link profile to data volume
    lvchange --metadataprofile "$vg_name-thinpool" "$vg_name/thinpool"
    # - Enable monitoring of data volume size, so that extension is triggered automatically
    lvs -o+seg_monitor

    # Re-enable benign warnings
    unset LVM_SUPPRESS_FD_WARNINGS
}

# PMK-1499 - Pods will be stuck in terminating for RHEL/CentOS hosts if this option is not set.
function set_detach_mounts
{
    # Check if fs.may_detach_mounts is present and enabled
    echo "Checking if fs.may_detach_mounts is enabled..."
    if ! grep -q -E '^fs.may_detach_mounts=1$' /etc/sysctl.conf; then
        echo "Parameter isn't enabled. Setting enabled..."
        # If the option does not exist or is not enabled, remove it
        sed -i '/^fs.may_detach_mounts=/d' /etc/sysctl.conf
        # Persist and set the option
        echo "fs.may_detach_mounts=1" >> /etc/sysctl.conf
        sysctl -q -p
        echo "Parameter 'fs.may_detach_mounts' enabled and persisted successfully"
    fi
}

get_host_os
case "$host_os" in
    redhat)
        create_thinpool_from_block_device "/dev/xvdb" "docker-vg"
        set_detach_mounts
        ;;
    debian)
        create_persistent_mount_from_block_device "/dev/xvdb" "/var/lib/docker/aufs/"
        ;;
    *)
        echo "secondary block device configuration: skipping because \'$host_os\' is unknown OS"
        ;;
esac
generate_qbert_metadata
if [[ "${hostagent_installer_type}" = "legacy" ]]; then
    get_token
fi
install_host_agent

chown -R pf9:pf9group /etc/pf9/
