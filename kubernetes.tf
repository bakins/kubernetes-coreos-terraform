provider "aws" {
    access_key = "${var.access_key}"
    secret_key = "${var.secret_key}"
    region = "${var.region}"
}

resource "aws_vpc" "kubernetes" {
    cidr_block = "172.20.0.0/16"
    enable_dns_support = true
    enable_dns_hostnames = true
    tags {
        Name = "kubernetes-${var.cluster_name}"
    }
}

resource "aws_subnet" "kubernetes" {
    vpc_id = "${aws_vpc.kubernetes.id}"
    cidr_block = "172.20.250.0/24"

    tags {
        Name = "kubernetes-${var.cluster_name}"
    }
}

resource "aws_route_table" "kubernetes" {
    vpc_id = "${aws_vpc.kubernetes.id}"
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.kubernetes.id}"
    }
    tags {
        Name = "kubernetes-${var.cluster_name}"
    }
}

resource "aws_internet_gateway" "kubernetes" {
    vpc_id = "${aws_vpc.kubernetes.id}"
    tags {
        Name = "kubernetes-${var.cluster_name}"
    }
}

resource "aws_route_table_association" "kubernetes" {
    subnet_id = "${aws_subnet.kubernetes.id}"
    route_table_id = "${aws_route_table.kubernetes.id}"
}

resource "aws_security_group" "kubernetes" {
    name = "kubernetes-${var.cluster_name}"
    vpc_id = "${aws_vpc.kubernetes.id}"

    tags {
        Name = "kubernetes-${var.cluster_name}"
    }
}

resource "aws_security_group_rule" "allow_ssh" {
    type = "ingress"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_group_id = "${aws_security_group.kubernetes.id}"
}

resource "aws_security_group_rule" "allow_kube_api" {
    type = "ingress"
    from_port = 6443
    to_port = 6443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_group_id = "${aws_security_group.kubernetes.id}"
}

resource "aws_security_group_rule" "allow_all_cluster" {
    type = "ingress"
    from_port = 0
    to_port = 65535
    protocol = "-1"
    source_security_group_id = "${aws_security_group.kubernetes.id}"
    security_group_id = "${aws_security_group.kubernetes.id}"
}

resource "aws_security_group_rule" "allow_all_egress" {
    type = "egress"
    from_port = 0
    to_port = 65535
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    security_group_id = "${aws_security_group.kubernetes.id}"
}

resource "template_file" "kubernetes" {
    filename = "templates/kubernetes.sh"

    vars = {
        etcd_dicovery_url = "${replace(file("etcd_discovery_url.txt"), "/\n/", "")}"
        containers_cidr = "${var.containers_cidr}"
        kubernetes_version = "${var.kubernetes_version}"
        portal_net = "${var.portal_net}"
    }
}

resource "template_file" "tokens" {
    filename = "templates/tokens.csv"

    vars = {
        token = "${replace(file("kube_token.txt"), "/\n/", "")}"
    }
}

resource "aws_instance" "etcd" {
    ami = "${var.ami}"
    instance_type = "t2.medium"
    count = "${var.num_etcd}"
    security_groups = [ "${aws_security_group.kubernetes.id}" ]
    subnet_id = "${aws_subnet.kubernetes.id}"
    associate_public_ip_address = true
    key_name = "${var.ssh_key_name}"

    connection {
        user = "core"
        agent = true
    }

    tags {
        Name = "kubernetes-${var.cluster_name}-etcd"
        Cluster = "${var.cluster_name}"
        Role = "etcd"
    }


    provisioner "file" {
        source = "scripts/${self.tags.Role}.sh"
        destination = "/tmp/${self.tags.Role}.sh"
    }

    provisioner "remote-exec" {
        inline = [
            "echo 'PRIVATE_IP=${self.private_ip}' > /tmp/network.env",
            "echo 'PUBLIC_IP=${self.public_ip}' >> /tmp/network.env",
            "sudo mv /tmp/network.env /etc/network.env",
            "cat <<'EOF' > /tmp/kubernetes.env\n${template_file.kubernetes.rendered}\nEOF",
            "sudo mv /tmp/kubernetes.env /etc/kubernetes.env",
            "sudo bash /tmp/${self.tags.Role}.sh"
        ]
    }
}
resource "aws_instance" "master" {
    ami = "${var.ami}"
    instance_type = "t2.medium"
    security_groups = [ "${aws_security_group.kubernetes.id}" ]
    subnet_id = "${aws_subnet.kubernetes.id}"
    associate_public_ip_address = true
    key_name = "${var.ssh_key_name}"

    connection {
        user = "core"
        agent = true
    }

    tags {
        Name = "kubernetes-${var.cluster_name}-master"
        Cluster = "${var.cluster_name}"
        Role = "master"
    }

    provisioner "file" {
        source = "scripts"
        destination = "/tmp/scripts"
    }

    provisioner "remote-exec" {
        inline = [
            "cat <<'EOF' > /tmp/tokens.csv\n${template_file.tokens.rendered}\nEOF",
            "sudo mkdir -p mkdir /etc/kubernetes",
            "sudo mv /tmp/tokens.csv /etc/kubernetes/tokens.csv",
            "echo 'PRIVATE_IP=${self.private_ip}' > /tmp/network.env",
            "echo 'PUBLIC_IP=${self.public_ip}' >> /tmp/network.env",
            "sudo mv /tmp/network.env /etc/network.env",
            "cat <<'EOF' > /tmp/kubernetes.env\n${template_file.kubernetes.rendered}\nEOF",
            "sudo mv /tmp/kubernetes.env /etc/kubernetes.env",
            "sudo bash /tmp/scripts/${self.tags.Role}.sh"
        ]
    }
}

resource "aws_instance" "worker" {
    ami = "${var.ami}"
    instance_type = "t2.medium"
    count = "${var.num_worker}"
    security_groups = [ "${aws_security_group.kubernetes.id}" ]
    subnet_id = "${aws_subnet.kubernetes.id}"
    associate_public_ip_address = true
    key_name = "${var.ssh_key_name}"

    connection {
        user = "core"
        agent = true
    }

    tags {
        Name = "kubernetes-${var.cluster_name}-worker"
        Cluster = "${var.cluster_name}"
        Role = "worker"
    }

    provisioner "file" {
        source = "scripts"
        destination = "/tmp/scripts"
    }

    provisioner "remote-exec" {
        inline = [
            "echo 'PRIVATE_IP=${self.private_ip}' > /tmp/network.env",
            "echo 'PUBLIC_IP=${self.public_ip}' >> /tmp/network.env",
            "sudo mv /tmp/network.env /etc/network.env",
            "cat <<'EOF' > /tmp/kubernetes.env\n${template_file.kubernetes.rendered}\nEOF",
            "echo 'KUBERNETES_MASTER=http://${aws_instance.master.private_ip}:8080' >> /tmp/kubernetes.env",
            "sudo mv /tmp/kubernetes.env /etc/kubernetes.env",
            "sudo bash /tmp/scripts/${self.tags.Role}.sh"
        ]
    }
}

resource "template_file" "kubectl-config" {
    filename = "templates/kubectl-config.sh"
    vars = {
        cluster_name = "${var.cluster_name}"
        token = "${replace(file("kube_token.txt"), "/\n/", "")}"
        server = "${aws_instance.master.public_ip}"
    }
}

output "kubernetes-api-server" {
    value = "${template_file.kubectl-config.rendered}"
}


