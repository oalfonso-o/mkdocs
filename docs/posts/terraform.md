# Terraform

To understand better what is [Terraform](https://www.terraform.io/intro) let's take a look to the description by [HashiCorp](https://www.hashicorp.com/):

> HashiCorp Terraform is an infrastructure as code tool that lets you define both cloud and on-prem resources in human-readable configuration files that you can version, reuse, and share. You can then use a consistent workflow to provision and manage all of your infrastructure throughout its lifecycle. Terraform can manage low-level components like compute, storage, and networking resources, as well as high-level components like DNS entries and SaaS features.

As with Ansible we can define all the configuration of a host, with Terraform we can define all the infrastructure, all the hosts that will exist, all the networking configuration, etc.

In this post we will go through the basic setup of Terraform with AWS to be able to replicate all our infrastructure in case of disaster or in case of needing to migrate from one AWS account to another (just to mention two examples).

## Requirements

You need an AWS account, you can create one with the [free tier](https://aws.amazon.com/free/?all-free-tier.sort-by=item.additionalFields.SortRank&all-free-tier.sort-order=asc&awsf.Free%20Tier%20Types=*all&awsf.Free%20Tier%20Categories=*all).

And this is not a requirement but this post assumes that you are using a Debian distro.

## Setup

Following the official [installation guide](https://learn.hashicorp.com/tutorials/terraform/install-cli?in=terraform/aws-get-started) we can run:

``` bash
$ apt-get update && apt-get install -y gnupg software-properties-common
$ wget -O- https://apt.releases.hashicorp.com/gpg | \
    gpg --dearmor | \
    tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
$ echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
    https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
    tee /etc/apt/sources.list.d/hashicorp.list
$ apt update
$ apt install terraform
```
!!! info ""

    We assume here that we are using the `root` user

We can check if it's properly installed with:

```
$ terraform --version
```

And it will tell you the installed version