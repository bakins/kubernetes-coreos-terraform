
# Use these commands to configure kubectl
kubectl config set-cluster ${cluster_name} --insecure-skip-tls-verify=true --server=https://${server}:6443
kubectl config set-credentials admin --token='${token}'
kubectl config set-context ${cluster_name} --cluster=${cluster_name} --user=admin
kubectl config use-context ${cluster_name}

