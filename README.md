# Platform9 Managed Kubernetes on Packet Baremetal
[![Platform9 Variables](docs/images/pmkft_thumbnail.png)](https://drive.google.com/file/d/1qGSSWqIxOLRodfkobgHz0e2su8f1ikoY/view)

This repo has [Terraform](http://terraform.io) plans to deploy a multi-master Kubernetes Cluster on Baremetal utilizing [Platform9 Managed Kubernetes](https://platform9.com/managed-kubernetes/) and [Packet (an Equinix Company)](https://packet.com). This deployment usually takes about 15 minutes to complete, and you'll have a Managed Kubernetes cluster ready to deploy workloads. Checkout the three and a half minute video above of this deployment!

## Instructions
### Create your Packet account
1. Sign up for a [Packet Public Cloud account](https://app.packet.net/signup)
2. Verify your e-mail address and login
3. Follow the wizard [Getting Started with Packet](https://app.packet.net/getting-started/overview) at  that guides you through creating a project.
    * You will need to put a Credit Card or PayPal on file, but use Promo Code ***BAREMETAL50*** for $50 in free credits
    * This four node stack will cost around $4.00 per hour.
4. [Upload and SSH key](https://www.packet.com/developers/docs/servers/key-features/ssh-keys/) to your Packet account.
5. Generate and Record a [Packet API Key](https://www.packet.com/developers/docs/API/) for future use
6. Locate and Record your [Packet Organization ID](https://app.packet.net/) for future use
    * Located under the **Settings** section of the **Top Right Drop Down Menu**
### Sign up for the Platform9 Managed Kubernetes Free Tier
1. Sign up for a [Platform9 Free Account](https://platform9.com/signup/)
2. Verify your e-mail address and login
3. Record the Following:
![Platform9 Variables](docs/images/pf9_variables.png)
    A. Platform9 Account Domain
    
    B. Platform9 Region (if different from pictured)
    
    C. Platorm9 Tenant (if different from pictured)
    
    D. Platform9 Username (e-mail address)
    
    E. Platform9 Password
### Install Terraform 
[Terraform](http://terraform.io) is just a single binary.  Visit their [download page](https://www.terraform.io/downloads.html), choose your operating system, make the binary executable, and move it into your path. 
 
Here is an example for **macOS**: 
```bash 
curl -LO https://releases.hashicorp.com/terraform/0.12.29/terraform_0.12.29_darwin_amd64.zip 
unzip terraform_0.12.29_darwin_amd64.zip 
chmod +x terraform 
sudo mv terraform /usr/local/bin/ 
``` 
 
### Download this project
To download this project and get in the directory, run the following commands:

```bash
git clone https://github.com/c0dyhi11/pmkft-on-packet.git
cd pmkft-on-packet
```

### Initialize Terraform 
Terraform uses modules to deploy infrastructure. In order to initialize the modules your simply run: `terraform init`. This should download these modules into a hidden directory `.terraform` 

### Set your Terraform Variables
You will need to collect and set a few variables in order to authenticate to both Platform9 and Packet. These variables are stored in the form of `key=value` in a file named `terraform.tfvars`. Here is a quick example of how to create this file and what it should look like:
```bash 
cat <<EOF >terraform.tfvars 
packet_org_id="ekj8e156-e2fb-4e5b-b90e-090a067437ee"
packet_api_key="OG8MyWgrcg3ngf7rzAa8UTrh5sG6A3DE"
platform9_fqdn="pmkft-1234567890-09876.platform9.io"
platform9_user="user@example.com"
platform9_password="$tr0ngP@$$w0rd!"
EOF 
``` 
There's a whole slew of other variables to check out in the `variables.tf` file. These are set to fairly sane defaults. But if you'd like to use a different server type, change the number of servers, or change the location of these servers, you can override these settings just by adding those `key=value` pairs to the file above. 
### Deploy the PMK Cluster on Packet! 
 
All there is left to do now is to deploy the cluster: 
```bash 
terraform apply --auto-approve 
``` 
This should end with output similar to this: 
``` 
Apply complete! Resources: 17 added, 0 changed, 0 destroyed.

Outputs:

Master_IPs = [
  "136.144.51.87",
  "136.144.51.103",
  "136.144.51.93",
]
Master_LB_IP = 136.144.51.75
Worker_IPs = [
  "136.144.51.131",
]
``` 
### Deleting the PMK Cluster
Once you have deployed your cluster and had your fun. If you choose not to keep this cluster around for a long period of time. You can simply destroy it.

In order to destroy the cluster run the following command:
```bash 
terraform destroy --auto-approve 
``` 
This shoudl end with output similar to this:
```
Destroy complete! Resources: 17 destroyed. 
```
**NOTE:** The one thing that I haven't written yet is the cleanup of the Nodes in Platform9. They will show up under the ***Nodes*** section as disconnected until you delete them manually.

## Troubleshooting or Help
If you need help with Platform9 you can join their [Community Slack](https://slack.platform9.io)!

If you need help with Packet you can join their [Community Slack](https://slack.packet.com/)!
### Known issues
Since Platform9 doesn't have a Terraform Provider to Create and Destroy clusters, I had to write this as an "External Datasource
