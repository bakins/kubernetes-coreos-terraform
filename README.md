# Kubernetes on CoreOS in AWS using Terraform

Provision a [Kubernetes](http://kubernetes.io) cluster with [Terraform](https://www.terraform.io) on AWS.

Inspired by [kubestack](https://github.com/kelseyhightower/kubestack)

## Status

Hot off the presses... Still in development.

## Prep
- [Install Terraform](https://www.terraform.io/intro/getting-started/install.html)

## Terraform

Terraform will be used to declare and provision a Kubernetes cluster.

## Prep

Create a `terraform.tfvars` file in the top-level directory of the repo with content like:

```
ssh_key_name = name_of_my_key_pair_in_AWS
access_key = my_AWS_access_key
secret_key = my_AWS_secret_key
```

This file is ignored by git.  You can also set these by using [environment variables](https://www.terraform.io/docs/configuration/variables.html).

You also need to make sure you are running ssh-agent and have your AWS key added.

### Usage

This repo includes a very simple [Makefile](./Makefile) that will handle generating an etcd [discovery token](https://coreos.com/docs/cluster-management/setup/cluster-discovery/).

To create the cluster, run `make apply`

To destroy the cluster, run `make destroy`

You can override any variables listed in [variables.tf](./variables.tf) such as the ami to use, number of nodes, etc

## Next Steps

When you create a cluster, it will output something like:

```
Outputs:
  kubernetes-api-server =
# Use these commands to configure kubectl
kubectl config set-cluster testing --insecure-skip-tls-verify=true --server=IP
kubectl config set-credentials admin --token='4c98e411'
kubectl config set-context testing --cluster= testing --user=admin
kubectl config use-context testing
```

Run these commands to configure `kubectl`.  You can see these commands again by running `terraform output kubernetes-api-server`

Test this by running `kubectl get nodes`

Yuou should now be able to use `kubectl` to create services. See the [kubernetes examples](https://github.com/GoogleCloudPlatform/kubernetes/tree/master/examples) to get started.

## TODO

