import json
import sys
import qbert
from os import path


def load_cluster_data(json_file_name):
    if path.exists(json_file_name):
        with open(json_file_name) as json_file:
            cluster_data = json.load(json_file)
        if "cluster_id" in cluster_data and "node_pool_uuid" in cluster_data:
            return cluster_data
    return {}

      
def validate_cluster(cluster_data, auth, cluster_name, k8s_api_fqdn):
    if cluster_data.keys() >= ({"cluster_id", "node_pool_uuid"}):
        cluster = qbert.get_cluster(auth['qbert_url'], auth['token'], cluster_data['cluster_id'])
    else:
        return False
    if isinstance(cluster, int):
        return False
    if cluster.keys() >= ({"uuid", "nodePoolUuid", "name", "externalDnsName"}):
        if cluster["nodePoolUuid"] != cluster_data["node_pool_uuid"]:
            return False
        elif cluster["name"] != cluster_name:
            return False
        elif cluster["externalDnsName"] != k8s_api_fqdn:
            return False
    else:
        return False
    return True


def create_cluster(auth, cluster_name, k8s_api_fqdn, allow_workloads_on_master=False,
                   privileged_mode_enabled=True, app_catalog_enabled=False, runtime_config='',
                   networkPlugin='flannel', container_cidr='172.30.0.0/16', services_cidr='172.31.0.0/16',
                   mtuSize=1440, debug_flag=True):
    
    node_pool_uuid = qbert.get_node_pool(auth['qbert_url'], auth['token'])
    new_cluster = qbert.create_cluster(auth['qbert_url'], auth['token'], cluster_name, container_cidr, services_cidr,
                                       k8s_api_fqdn, privileged_mode_enabled, app_catalog_enabled,
                                       allow_workloads_on_master, runtime_config, node_pool_uuid,
                                       networkPlugin, debug_flag, mtuSize)
    output = {"cluster_id": new_cluster, "node_pool_uuid": node_pool_uuid}
    return output


def read_in():
    return {x.strip() for x in sys.stdin}


def pf9_auth(endpoint, user, pw, tenant, region):
    token, catalog, project_id = qbert.get_token_v3(endpoint, user, pw, tenant)
    qbert_url = "{0}/{1}".format(qbert.get_service_url('qbert', catalog, region), project_id)
    output = {"token": token, "catalog": catalog, "project_id": project_id, "qbert_url": qbert_url}
    return output


def main():
    """ Here is an example of how to call this script manually:
        printf '{"du_fqdn": "pmkft-1596142484-9999.platform9.io","user": "user@example.com","pw": "$tr0ngP@$$","tenant": "service","region": "RegionOne","cluster_name": "my_test_cluster","k8s_api_fqdn": "1.2.3.4", "privileged_mode_enabled": true}' | python3 create_cluster.py
    """
    json_file_name = ".pf9_cluster.json"
    lines = read_in()
    for line in lines:
        if line:
            options = json.loads(line)
    cluster_data = load_cluster_data(json_file_name)
    auth = pf9_auth(options['du_fqdn'], options['user'], options['pw'], options['tenant'], options['region'])
    valid_cluster = validate_cluster(cluster_data, auth, options['cluster_name'], options['k8s_api_fqdn'])
    if valid_cluster:
        sys.stdout.write(json.dumps(cluster_data))
    else:
        output = create_cluster(auth, options['cluster_name'], options['k8s_api_fqdn'], options['allow_workloads_on_master'])
        with open(json_file_name, 'w') as outfile:
            json.dump(output, outfile)
        sys.stdout.write(json.dumps(output))


if __name__ == "__main__":
    main()

