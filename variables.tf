variable "access_key" {}
variable "secret_key" {}

variable "region" {
    default = "us-west-2"
}

variable "ssh_key_name" {
    description = "Name of the SSH keypair to use in AWS."
}

variable "cluster_name" {
    default = "testing"
}

variable "containers_cidr" {
    default = "10.244.0.0/16"
}

variable "portal_net" {
    default = "10.0.0.0/16"
}

variable "num_etcd" {
    default = 3
}

variable "num_master" {
    default = 1
}

variable "num_worker" {
    default = 5
}

variable "ami" {
    default = "ami-23b58613"
}

variable "etcd_instance_type" {
    default = "t2.small"
}

variable "master_instance_type" {
    default = "t2.small"
}

variable "worker_instance_type" {
    default = "m3.medium"
}

variable "kubernetes_version" {
    default = "0.17.1"
}

variable "etcd_version" {
    description = "version of etcd to use"
    default = "2.0.11"
}

variable "pod_network" {
    default = "10.2.0.0/16"
}

variable "service_ip_range" {
    default = "10.3.0.0/24"
}

variable "k8s_service_ip" {
    default = "10.3.0.1"
}

variable "dns_service_ip" {
    default = "10.3.0.10"
}

variable "api_secure_port" {
    default = "443"
}

variable "master_dns_name" {
    default = ""
}