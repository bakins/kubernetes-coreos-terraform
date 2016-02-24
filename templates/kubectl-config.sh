 
# Use these commands to configure kubectl
kubectl config set-cluster ${cluster_name} --server=https://${server}:${api_secure_port} --certificate-authority=${cwd}/tls-assets/ca.pem
kubectl config set-credentials admin --certificate-authority=${cwd}/tls-assets/ca.pem --client-key=${cwd}/tls-assets/apiserver-key.pem --client-certificate=${cwd}/tls-assets/apiserver.pem
kubectl config set-context ${cluster_name} --cluster=${cluster_name} --user=admin
kubectl config use-context ${cluster_name}

# As an alternative you can run all kubectl commands with the --kubeconfig config pointing to the 'kubecfg' file in this folder. Example:
kubectl --kubeconfig=${cwd}/kubeconfig get pods

# ... or ...
export KUBECONFIG=${cwd}/kubeconfig
kubectl get pods

#Insecure config stuff
# kubectl config set-cluster ${cluster_name} --insecure-skip-tls-verify=true --server=http://${server}:8080
# kubectl config set-credentials admin --token='${token}'