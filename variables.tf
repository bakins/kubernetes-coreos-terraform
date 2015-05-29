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

variable "num_worker" {
    default = 5
}

variable "ami" {
    default = "ami-23b58613"
}

variable "kubernetes_version" {
    default = "0.17.1"
}

variable "etcd_version" {
    description = "version of etcd to use"
    default = "2.0.11"
}
