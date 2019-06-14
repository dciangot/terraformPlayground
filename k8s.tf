#provider "openstack" {
#  user_name   = "${var.username}"
#  password    = "${var.password}"
#  tenant_name = "${var.tenant}"
#  auth_url    = "http://openstack.fisica.unipg.it:5000/v3"
#  region      = "RegionOne"
#}

# TODO: use modules
variable "priv_network_name"{
  default = "tosca-private"
}

variable "pub_network_name"{
  default = "infn-farm"
}

variable "master_image_id" {
  default = "cb87a2ac-5469-4bd5-9cce-9682c798b4e4"
}

variable "slave_image_id" {
  default = "d9a41aed-3ebf-42f9-992e-ef0078d3de95"
}

variable "master_flavor_name" {
  default = "m1.medium"
}

variable "slave_flavor_name" {
  default = "m1.large"
}

variable "n_slaves" {
  default = 4
}

variable "volume_size" {
  default = 5
}

# GET keys previously generated
resource "openstack_compute_keypair_v2" "cluster-keypair" {
  name = "cluster-keypair"
  public_key = "${file("key.pub")}"
}

resource "openstack_blockstorage_volume_v2" "volumes" {
  count = "${var.n_slaves}"
  name        = "cache-${count.index}"
  size        = "${var.volume_size}"

}

# TODO: volumes e security groups
resource "openstack_compute_secgroup_v2" "secgroup_k8s" {
  name        = "secgroup_k8s"
  description = "security group for k8s with terraform"

  rule {
    from_port   = 22
    to_port     = 22
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }


  rule {
    from_port   = 6443
    to_port     = 6443
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }
}

resource "openstack_compute_instance_v2" "k8s-master" {
  count = 2
  name      = "master-${count.index}"
  image_id  = "${var.master_image_id}"
  flavor_name = "${var.master_flavor_name}"
  key_pair  = "${openstack_compute_keypair_v2.cluster-keypair.name}"
  security_groups = ["default", "${openstack_compute_secgroup_v2.secgroup_k8s.name}"]
  #security_groups = ["default"]
  network {
    name = "${var.priv_network_name}"
    #access_network = true
  }

  network {
    name = "${var.pub_network_name}"
    access_network = true
  }

}

resource "openstack_compute_instance_v2" "k8s-nodes" {
  name      = "node-${count.index}"
  count = "${var.n_slaves}"
  image_id  = "${var.slave_image_id}"
  flavor_name = "${var.slave_flavor_name}"
  key_pair  = "${openstack_compute_keypair_v2.cluster-keypair.name}"
  security_groups = ["default"]

  network {
    name = "${var.priv_network_name}"
  }

  depends_on = [
    openstack_compute_instance_v2.k8s-master
    ]
}

#resource "openstack_compute_volume_attach_v2" "attachments" {
#  count       = "${var.n_slaves}"
#  device = "auto"
#  instance_id = "${openstack_compute_instance_v2.k8s-nodes.*.id[count.index]}"
#  volume_id   = "${openstack_blockstorage_volume_v2.volumes.*.id[count.index]}"
#}

resource "openstack_networking_floatingip_v2" "floatingip_master" {
  count = 0
  pool = "ext-net"
}

resource "openstack_compute_floatingip_associate_v2" "floatingip_master" {
  count = 0
  floating_ip = "${openstack_networking_floatingip_v2.floatingip_master.*.address[count.index]}"
  instance_id = "${openstack_compute_instance_v2.k8s-master.*.id[count.index]}"
}

resource "null_resource" "cluster_setup" {

  triggers = {
    #floating_ip = "${openstack_compute_floatingip_associate_v2.floatingip_master.0.id}"
    ip = "${openstack_compute_instance_v2.k8s-master.0.id}"
  }

  provisioner "local-exec" {
    #command = "sleep 90 && scp -o \"StrictHostKeyChecking no\" -i key key ubuntu@${openstack_networking_floatingip_v2.floatingip_master.0.address}:~/.ssh/id_rsa"
    command = "sleep 90 && scp -o \"StrictHostKeyChecking no\" -i key key ubuntu@${openstack_compute_instance_v2.k8s-master.0.access_ip_v4}:~/.ssh/id_rsa"
  }

  provisioner "local-exec" {
    #command = "scp -o \"StrictHostKeyChecking no\" -i key key.pub ubuntu@${openstack_networking_floatingip_v2.floatingip_master.0.address}:~/.ssh/id_rsa.pub"
    command = "sleep 90 && scp -o \"StrictHostKeyChecking no\" -i key key ubuntu@${openstack_compute_instance_v2.k8s-master.0.access_ip_v4}:~/.ssh/id_rsa.pub"
  }

  provisioner "file" {
    source      = "scripts/install.sh"
    destination = "/tmp/install.sh"
    connection {
      type     = "ssh"
      user     = "ubuntu"
      #host = "${openstack_networking_floatingip_v2.floatingip_master.0.address}"
      host = "${openstack_compute_instance_v2.k8s-master.0.access_ip_v4}"
      private_key = "${file("key")}"
    }
  }
}

resource "null_resource" "install" {

    triggers = {
    floating_ip = "${null_resource.cluster_setup.id}"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install.sh",
      "chmod 600 ~/.ssh/id_rsa",
      "export HOSTS=\"(${join(" ",openstack_compute_instance_v2.k8s-master[*].access_ip_v4)} ${join(" ", openstack_compute_instance_v2.k8s-nodes[*].access_ip_v4)})\"",
      "/tmp/install.sh"
    ]
    connection {
      type     = "ssh"
      user     = "ubuntu"
      #host = "${openstack_networking_floatingip_v2.floatingip_master.0.address}"
      host = "${openstack_compute_instance_v2.k8s-master.0.access_ip_v4}"
      private_key = "${file("key")}"
  }
  }
}

output "master_ips" {
  #value = ["${openstack_networking_floatingip_v2.floatingip_master[*].address}"]
  value = ["${openstack_compute_instance_v2.k8s-master[*].access_ip_v4}"]

}

output "node_ips" {
  value = "${openstack_compute_instance_v2.k8s-nodes[*].access_ip_v4}"
}

output "dashboard_url" {
  #value = ["https://${openstack_networking_floatingip_v2.floatingip_master.0.address}:6443/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/#!/login"]
  value = ["https://${openstack_compute_instance_v2.k8s-master.0.access_ip_v4}:6443/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/#!/login"]
}