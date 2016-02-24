resource "template_file" "etcd-user-data" {
  template = "${file("user-data/etcd.yaml")}"

  vars = {
    etcd_discovery_url = "${replace(file("etcd_discovery_url.txt"), "/\n/", "")}"
  }
}

resource "template_file" "master-user-data" {
  template = "${file("user-data/master.yaml")}"

  vars = {
    etcd_discovery_url = "${replace(file("etcd_discovery_url.txt"), "/\n/", "")}"
    FLANNELD_ETCD_ENDPOINTS = "${join(",",formatlist("http://%s:2379",aws_instance.etcd.*.private_ip))}"
    KUBERNETES_CONTAINERS_CIDR = "${var.pod_network}"
    DNS_SERVICE_IP = "${var.dns_service_ip}"
  }
}

resource "template_file" "worker-user-data" {
  template = "${file("user-data/worker.yaml")}"

  vars = {
    etcd_discovery_url = "${replace(file("etcd_discovery_url.txt"), "/\n/", "")}"
    FLANNELD_ETCD_ENDPOINTS = "${join(",",formatlist("http://%s:2379",aws_instance.etcd.*.private_ip))}"
    KUBERNETES_VERSION = "${var.kubernetes_version}"
    MASTER_HOSTS = "${join(",",formatlist("https://%s:%s",aws_instance.master.*.private_ip,var.api_secure_port))}"
    DNS_SERVICE_IP = "${var.dns_service_ip}"
    ca_pem = "${base64encode(file("tls-assets/ca.pem"))}"
    ca_key_pem = "${base64encode(file("tls-assets/ca-key.pem"))}"
    # DNS_SERVICE_IP = "${var.dns_service_ip}"
    # MASTER_HOSTS = "${join(",",formatlist("https://%s",aws_instance.master.*.private_ip))}"
  }
}

resource "template_file" "openssl" {
  template = "${file("templates/openssl.cnf")}"
  vars = {
    k8s_service_ip = "${var.k8s_service_ip}"
    master_dns = "${replace("DNS.3 = ${var.master_dns_name}\n", "/^DNS.3 = \n/", "")}"
    instancelist = "${join("\n",formatlist("IP.%v = %s\nIP.%v = %s",count.index * 2 + 2,aws_instance.master.*.public_ip,count.index * 2 + 3,aws_instance.master.*.private_ip))}"
  }
}

resource "template_file" "kubectl-config-file" {
  template = "${file("templates/kubecfg.yaml")}"

  vars = {
    cluster_name = "${var.cluster_name}"
    token = "${replace(file("kube_token.txt"), "/\n/", "")}"
    master_ip = "${element(aws_instance.master.*.public_ip,0)}"
    api_secure_port = "${var.api_secure_port}"
    cwd = "${path.cwd}"
  }
}

resource "template_file" "create-master-tls" {
  template = "templates/create-master-tls"
}

resource "template_file" "create-admin-tls" {
  template = "templates/create-admin-tls"
}

resource "template_file" "master-env" {
  template = "templates/master.env"
  vars = {
    KUBERNETES_VERSION = "${var.kubernetes_version}"
    ETCD_ENDPOINTS = "${join(",",formatlist("http://%s:2379",aws_instance.etcd.*.private_ip))}"
    SERVICE_IP_RANGE = "${var.service_ip_range}"
    API_SECURE_PORT = "${var.api_secure_port}"
  }
}

resource "template_file" "init-kubernetes" {
  template = "templates/init-kubernetes.sh"
  vars = {
    ETCD_SERVER = "http://${element(aws_instance.etcd.*.private_ip,0)}:2379"
    POD_NETWORK = "${var.pod_network}"
  }
}

# resource "template_file" "tokens" {
#   template = "templates/tokens.csv"
#   vars = {
#       token = "${replace(file("kube_token.txt"), "/\n/", "")}"
#   }
# }

resource "template_file" "kubectl-config" {
  template = "templates/kubectl-config.sh"
  vars = {
      cluster_name = "${var.cluster_name}"
      token = "${replace(file("kube_token.txt"), "/\n/", "")}"
      server = "${element(aws_instance.master.*.public_ip,0)}"
      api_secure_port = "${var.api_secure_port}"
      cwd = "${path.cwd}"
  }
}