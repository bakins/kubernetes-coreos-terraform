plan: etcd_discovery_url.txt
	terraform plan

etcd_discovery_url.txt:
	curl -s https://discovery.etcd.io/new?size=3 > etcd_discovery_url.txt

destroy:
	terraform destroy
	rm etcd_discovery_url.txt

apply: etcd_discovery_url.txt
	terraform apply
