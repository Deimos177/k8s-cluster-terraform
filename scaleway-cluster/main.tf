terraform {
  required_providers {
    scaleway = {
      source = "scaleway/scaleway"
    }
  }
  required_version = ">= 0.13"
}

variable "access_key" {
  type      = string
  sensitive = true
}
variable "secret_key" {
  type      = string
  sensitive = true
}
variable "organization_id" {
  type      = string
  sensitive = true
}
variable "project_id" {
  type      = string
  sensitive = true
}
provider "scaleway" {
  access_key      = var.access_key
  secret_key      = var.secret_key
  organization_id = var.organization_id
  project_id      = var.project_id
}
resource "scaleway_vpc_private_network" "study" {
  name   = "study_network"
  tags   = ["Study", "k8s"]
  vpc_id = "80e14cba-0971-4edc-aa0e-3b16eba9599a"
}

resource "scaleway_k8s_cluster" "study" {
  name                        = "Bruce"
  description                 = "my study cluster"
  version                     = "1.29.1"
  cni                         = "calico"
  tags                        = ["Study", "k8s"]
  private_network_id          = scaleway_vpc_private_network.study.id
  delete_additional_resources = false
}

resource "scaleway_k8s_pool" "study" {

  depends_on  = [scaleway_k8s_cluster.study]
  cluster_id  = scaleway_k8s_cluster.study.id
  name        = "bruce"
  node_type   = "DEV1-M"
  size        = 3
  autoscaling = false
  autohealing = true
  min_size    = 1
  max_size    = 3
}