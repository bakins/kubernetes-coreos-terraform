#!/bin/bash

until curl -o /dev/null -sf "${ETCD_SERVER}/version"; do sleep 5 && echo "Checking ETCD readiness to setup Pod Network"; done;
curl -X PUT -d "value={\"Network\":\"${POD_NETWORK}\",\"Backend\":{\"Type\":\"vxlan\"}}" "${ETCD_SERVER}/v2/keys/coreos.com/network/config"

until curl -o /dev/null -sf "http://127.0.0.1:8080/version"; do sleep 5 && echo "Checking K8s readiness to init 'kube-system' namespace"; done;
curl -XPOST -d'{"apiVersion":"v1","kind":"Namespace","metadata":{"name":"kube-system"}}' "http://127.0.0.1:8080/api/v1/namespaces"