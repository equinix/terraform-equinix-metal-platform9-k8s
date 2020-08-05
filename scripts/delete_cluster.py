import json
import sys
import qbert
from os import path


def read_in():
    return {x.strip() for x in sys.stdin}


def pf9_auth(endpoint, user, pw, tenant, region):
    token, catalog, project_id = qbert.get_token_v3(endpoint, user, pw, tenant)
    qbert_url = "{0}/{1}".format(qbert.get_service_url('qbert', catalog, region), project_id)
    output = {"token": token, "catalog": catalog, "project_id": project_id, "qbert_url": qbert_url}
    return output


def delete_cluster(auth, cluster_id):
    delete_cluster = qbert.delete_request(qbert_url, token, "clusters/{}".format(cluster_id))

    return delete_cluster


def main():
    """ Here is an example of how to call this script manually:
        printf '{"du_fqdn": "pmkft-1596142484-9999.platform9.io","user": "user@example.com","pw": "$tr0ngP@$$","tenant": "service","region": "RegionOne","cluster_name": "my_test_cluster","k8s_api_fqdn": "1.2.3.4"}' | python3 create_cluster.py
    """
    lines = read_in()
    for line in lines:
        if line:
            options = json.loads(line)
    auth = pf9_auth(options['du_fqdn'], options['user'], options['pw'], options['tenant'], options['region'])
    delete_cluster = qbert.delete_request(auth['qbert_url'], auth['token'], "clusters/{}".format(options['cluster_uuid']))


if __name__ == "__main__":
    main()
	
