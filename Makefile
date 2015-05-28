plan: etcd_discovery_url.txt kube_token.txt
	terraform plan

etcd_discovery_url.txt:
	curl -s https://discovery.etcd.io/new?size=3 > etcd_discovery_url.txt

destroy:
	terraform destroy
	rm etcd_discovery_url.txt kube_token.txt

apply: etcd_discovery_url.txt kube_token.txt
	terraform apply

kube_token.txt:
	openssl rand -base64 8 |md5 |head -c8 > kube_token.txt
	echo >> kube_token.txt
