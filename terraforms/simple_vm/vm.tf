variable "priv_network_name"{
}

#variable "pub_network_name"{
#}

variable "new_keypair_name"{
}

variable "new_keypair_path" {
  default = "key.pub"
}


variable "floating_ip" {
  description = "Do you want to bind a floating IP? (yes:1 no:0)"
}


variable "vm_image_id" {
}

variable "vm_flavor_name" {
}


variable "n_vms" {
}

variable "mount_volumes" {
  description = "Do you want to bind external volumes? (yes:1 no:0)"
  default = 0
}

variable "n_external_volumes" {
  default = 0
}

variable "volume_size" {
  default = 0
}

# GET keys previously generated
resource "openstack_compute_keypair_v2" "cluster-keypair" {
  name = "${var.new_keypair_name}"
  public_key = "${file("${var.new_keypair_path}")}"
}

resource "openstack_blockstorage_volume_v2" "volumes" {
  count = "${var.n_external_volumes}"
  name        = "terraform-${count.index}"
  size        = "${var.volume_size}"
}

resource "openstack_networking_floatingip_v2" "floatingip_vm" {
  count = "${var.floating_ip}"
  pool = "ext-net"
}

resource "openstack_compute_secgroup_v2" "secgroup_k8s" {
  name        = "secgroup_spray-k8s"
  description = "security group for k8s with terraform"

  rule {
    from_port   = 22
    to_port     = 22
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }

}

resource "openstack_compute_instance_v2" "vm" {
  count = "${var.n_vms}"
  name      = "vm-${count.index}"
  image_id  = "${var.vm_image_id}"
  flavor_name = "${var.vm_flavor_name}"
  key_pair  = "${openstack_compute_keypair_v2.cluster-keypair.name}"
  security_groups = ["default", "${openstack_compute_secgroup_v2.secgroup_k8s.name}"]
  network {
    name = "${var.priv_network_name}"
    #access_network = true
  }

  #network {
  #  name = "${var.pub_network_name}"
  #  access_network = true
  #}

}

resource "openstack_compute_volume_attach_v2" "attachments" {
   count       = "${var.n_external_volumes}"
   instance_id = "${openstack_compute_instance_v2.vm.*.id[count.index]}"
   volume_id   = "${openstack_blockstorage_volume_v2.volumes.*.id[count.index]}"
   device = "/dev/vdc"
}

resource "openstack_compute_floatingip_associate_v2" "floatingip_vm" {
  count = "${var.floating_ip}"
  floating_ip = "${openstack_networking_floatingip_v2.floatingip_vm.*.address[count.index]}"
  instance_id = "${openstack_compute_instance_v2.vm.*.id[count.index]}"
}

resource "null_resource" "mount_volumes" {
  count = "${var.mount_volumes}"
  triggers = {
    attach = "${openstack_compute_volume_attach_v2.attachments.0.id}"
  }

  provisioner "file" {
    source      = "tasks/mount.yaml"
    destination = "/tmp/mount.yaml"
    connection {
      type     = "ssh"
      user     = "ubuntu"
      host = "${openstack_networking_floatingip_v2.floatingip_vm.0.address}"
      #host = "${openstack_compute_instance_v2.k8s-master.0.access_ip_v4}"
      private_key = "${file("key")}"
    }
  }

  provisioner "remote-exec" {
    inline = [
      "cd kubespray",
      "ansible-playbook -i inventory/mycluster/hosts.yml --become --become-user=root /tmp/mount.yaml"
    ]
    connection {
      type     = "ssh"
      user     = "ubuntu"
      host =  "${openstack_networking_floatingip_v2.floatingip_vm.0.address}"
      private_key = "${file("key")}"
  }
  }

}


output "master_ips" {
  value = ["${openstack_networking_floatingip_v2.floatingip_vm.*.address}"]
  #value = ["${openstack_compute_instance_v2.vm[*].access_ip_v4}", "${openstack_compute_instance_v2.vm[*].network.0.fixed_ip_v4}"]
}

