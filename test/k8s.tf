# variable "os_username" {
#   type = string
# }

# variable "os_password" {
#   type = string
# }

# variable "os_tenant" {
#   type = string
# }


# provider "openstack" {
#   user_name   = var.os_username
#   password    = var.os_password
#   tenant_name = var.os_tenant
#   auth_url    = "http://openstack.fisica.unipg.it:5000/v3"
#   region      = "RegionOne"
# }

# TODO: use modules
variable "priv_network_name"{
  default = "net"
  #default = "private_net"
}

variable "pub_network_name"{
  default = "infn-farm"
  #default = "public_net"
}

variable "master_image_id" {
  default = "cb87a2ac-5469-4bd5-9cce-9682c798b4e4"
  #default = "8f667fbc-40bf-45b8-b22d-40f05b48d060"
}

variable "slave_image_id" {
  default = "d9a41aed-3ebf-42f9-992e-ef0078d3de95"
  #default = "8f667fbc-40bf-45b8-b22d-40f05b48d060"
}

variable "master_flavor_name" {
  default = "m1.large"
  #default = "2cpu-4GB.dodas"
}

variable "slave_flavor_name" {
  default = "m1.xlarge"
  #default = "2cpu-4GB.dodas"
}

variable "n_slaves" {
  default =4 
}

variable "mount_volumes" {
  default = 1
}

variable "n_external_volumes" {
  default = 2
}

variable "volume_size" {
  default = 50
}


resource "openstack_compute_instance_v2" "k8s-nodes" {
  name      = "node-${count.index}"
  count = "${var.n_slaves}"
  image_id  = "${var.slave_image_id}"
  flavor_name = "${var.slave_flavor_name}"
  key_pair  = "dciangot"
  security_groups = ["default"]

  network {
    name = "${var.priv_network_name}"
  }

}

