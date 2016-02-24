plan: etcd_discovery_url.txt kube_token.txt tls-assets/ca-key.pem tls-assets/ca.pem
	terraform plan

etcd_discovery_url.txt:
	curl -s https://discovery.etcd.io/new?size=2 > etcd_discovery_url.txt

destroy:
	terraform destroy
	rm etcd_discovery_url.txt kube_token.txt
	rm -rf tls-assets

apply: etcd_discovery_url.txt kube_token.txt tls-assets/ca-key.pem tls-assets/ca.pem
	terraform apply

kube_token.txt:
	openssl rand -base64 8 |md5 |head -c8 > kube_token.txt
	echo >> kube_token.txt

tls-assets/ca-key.pem:
	mkdir -p tls-assets
	openssl genrsa -out tls-assets/ca-key.pem 2048

tls-assets/ca.pem:
	mkdir -p tls-assets
	openssl req -x509 -new -nodes -key tls-assets/ca-key.pem -days 10000 -out tls-assets/ca.pem -subj "/CN=kube-ca"