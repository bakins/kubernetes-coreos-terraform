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
    from_port = "${var.api_secure_port}"
    to_port = "${var.api_secure_port}"
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

resource "aws_instance" "etcd" {
    ami = "${var.ami}"
    instance_type = "${var.etcd_instance_type}"
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
        Name = "${var.cluster_name}-etcd"
        Cluster = "${var.cluster_name}"
        Role = "etcd"
    }

    user_data = "${template_file.etcd-user-data.rendered}"
}

resource "aws_iam_instance_profile" "master" {
    name = "k8s-master"
    roles = ["${aws_iam_role.master.name}"]
}

resource "aws_iam_role_policy" "master" {
    name = "k8s-master"
    role = "${aws_iam_role.master.id}"
    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:*"
            ],
            "Resource": [
                "*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:*"
            ],
            "Resource": [
                "*"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_role" "master" {
    name = "k8s-master"
    path = "/"
    assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_instance" "master" {
    ami = "${var.ami}"
    instance_type = "${var.master_instance_type}"
    count = "${var.num_master}"
    iam_instance_profile = "${aws_iam_instance_profile.master.name}"
    security_groups = [ "${aws_security_group.kubernetes.id}" ]
    subnet_id = "${aws_subnet.kubernetes.id}"
    associate_public_ip_address = true
    key_name = "${var.ssh_key_name}"

    connection {
        user = "core"
        agent = true
    }

    tags {
        Name = "${var.cluster_name}-master"
        Cluster = "${var.cluster_name}"
        Role = "master"
    }

    provisioner "file" {
        source = "scripts"
        destination = "/tmp/scripts"
    }

    provisioner "remote-exec" {
        inline = [
            "cat <<'EOF' > /tmp/kubernetes.env\n${template_file.master-env.rendered}\nEOF",
            "echo 'PRIVATE_IP=${self.private_ip}' >> /tmp/kubernetes.env",
            "echo 'PUBLIC_IP=${self.public_ip}' >> /tmp/kubernetes.env",
            "sudo mv /tmp/kubernetes.env /etc/kubernetes.env",
            "sudo bash /tmp/scripts/master.sh",
            # "cat << 'EOF' > /tmp/kubernetes/tokens.csv\n${template_file.tokens.rendered}\nEOF",
            "sudo mkdir -p /etc/kubernetes/ssl"
            # "sudo mv /tmp/kubernetes/tokens.csv /etc/kubernetes/ssl/tokens.csv",
        ]
    }

    user_data = "${template_file.master-user-data.rendered}"
}

resource "null_resource" "master" {
    count = "${var.num_master}"
    triggers {
        cluster_instance_ids = "${join(",", aws_instance.master.*.id)}"
    }
    connection {
        host = "${element(aws_instance.master.*.public_ip, count.index)}"
        user = "core"
        agent = true
    }
    provisioner "remote-exec" {
        inline = [
            "sudo rm -rf /tmp/ssl",
            "sudo rm -rf /etc/kubernetes/ssl",
            "mkdir /tmp/ssl",
            "sudo mkdir -p /etc/kubernetes"
        ]
    }
    provisioner "local-exec" {
        command = "cat << 'EOF' > tls-assets/openssl.cnf\n${template_file.openssl.rendered}\nEOF\n${template_file.create-master-tls.rendered} && scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -q tls-assets/ca.pem tls-assets/apiserver.pem tls-assets/apiserver-key.pem core@${element(aws_instance.master.*.public_ip, count.index)}:/tmp/ssl/"
    }
    provisioner "remote-exec" {
        inline = [
            "sudo mv /tmp/ssl /etc/kubernetes/ssl",
            "sudo chmod 600 /etc/kubernetes/ssl/*-key.pem",
            "sudo chown root:root /etc/kubernetes/ssl/*-key.pem"
        ]
    }
}

resource "aws_iam_role_policy" "worker" {
    name = "k8s-worker"
    role = "${aws_iam_role.worker.id}"
    policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "ec2:Describe*",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "ec2:AttachVolume",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "ec2:DetachVolume",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:GetRepositoryPolicy",
        "ecr:DescribeRepositories",
        "ecr:ListImages",
        "ecr:BatchGetImage"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "worker" {
    name = "k8s-worker"
    roles = ["${aws_iam_role.worker.name}"]
}

resource "aws_iam_role" "worker" {
    name = "k8s-worker"
    path = "/"
    assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_launch_configuration" "worker" {
    image_id = "${var.ami}"
    instance_type = "${var.worker_instance_type}"
    iam_instance_profile = "${aws_iam_instance_profile.worker.name}"
    security_groups = [ "${aws_security_group.kubernetes.id}" ]
    associate_public_ip_address = true
    key_name = "${var.ssh_key_name}"


    user_data = "${template_file.worker-user-data.rendered}"
}

resource "aws_autoscaling_group" "worker" {
    name = "${var.cluster_name}-k8s-worker"
    launch_configuration = "${aws_launch_configuration.worker.name}"
    max_size = "${var.num_worker}"
    min_size = "${var.num_worker}"
    desired_capacity = "${var.num_worker}"
    vpc_zone_identifier = [ "${aws_subnet.kubernetes.id}" ]


    tag {
        key = "Name"
        value = "${var.cluster_name}-worker"
        propagate_at_launch = true
    }

    tag {
        key = "Cluster"
        value = "${var.cluster_name}"
        propagate_at_launch = true
    }

    tag {
        key = "Role"
        value = "worker"
        propagate_at_launch = true
    }
}

resource "null_resource" "init-kubernetes" {
    triggers {
        id = "${element(aws_instance.master.*.id,0)}"
    }
    connection {
        host = "${element(aws_instance.master.*.public_ip, 0)}"
        user = "core"
        agent = true
    }
    provisioner "remote-exec" {
        inline = [
            "${template_file.init-kubernetes.rendered}"
        ]
    }
    provisioner "local-exec" {
        command = "${template_file.create-admin-tls.rendered}"
    }

    provisioner "local-exec" {
        command = "cat <<EOF > kubeconfig\n${template_file.kubectl-config-file.rendered}\nEOF"
    }
}

output "kubernetes-api-server" {
    value = "${template_file.kubectl-config.rendered}"
}