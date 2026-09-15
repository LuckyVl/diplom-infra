locals {
  k8s_cloud_init     = file("${path.module}/cloud-init-k8s.yaml")
  bastion_cloud_init = file("${path.module}/cloud-init-bastion.yaml")
  ssh_public_key     = file(var.ssh_public_key_path)
}

resource "yandex_vpc_network" "diplom_vpc" {
  name = var.vpc_name
}

resource "yandex_vpc_gateway" "nat_gateway" {
  name = "diplom-nat-gateway"
  shared_egress_gateway {}
}

resource "yandex_vpc_route_table" "nat_route_table" {
  network_id = yandex_vpc_network.diplom_vpc.id
  name       = "diplom-nat-route-table"

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.nat_gateway.id
  }
}

resource "yandex_vpc_subnet" "diplom_subnets" {
  for_each = var.subnet_cidrs

  name           = "diplom-subnet-${each.key}"
  zone           = each.key
  network_id     = yandex_vpc_network.diplom_vpc.id
  v4_cidr_blocks = [each.value]
  route_table_id = yandex_vpc_route_table.nat_route_table.id
}

resource "yandex_vpc_security_group" "bastion_sg" {
  name       = "bastion-sg"
  network_id = yandex_vpc_network.diplom_vpc.id

  ingress {
    protocol       = "TCP"
    v4_cidr_blocks = [var.my_ip]
    port           = 22
  }

  ingress {
    protocol       = "ICMP"
    v4_cidr_blocks = ["10.50.0.0/16"]
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}

resource "yandex_vpc_security_group" "k8s_sg" {
  name       = "k8s-sg"
  network_id = yandex_vpc_network.diplom_vpc.id

  ingress {
    protocol       = "TCP"
    v4_cidr_blocks = [yandex_vpc_subnet.diplom_subnets["ru-central1-a"].v4_cidr_blocks[0]]
    port           = 22
  }

  ingress {
    protocol       = "TCP"
    v4_cidr_blocks = ["10.50.0.0/16"]
    port           = 6443
  }

  ingress {
    protocol       = "TCP"
    v4_cidr_blocks = ["10.50.0.0/16"]
    port           = 10250
  }

  ingress {
    protocol       = "TCP"
    v4_cidr_blocks = ["10.50.0.0/16"]
    from_port      = 30000
    to_port        = 32767
  }

  ingress {
    protocol       = "ICMP"
    v4_cidr_blocks = ["10.50.0.0/16"]
  }

  ingress {
    protocol       = "ANY"
    v4_cidr_blocks = ["10.50.0.0/16"]
    from_port      = 0
    to_port        = 65535
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}

resource "yandex_vpc_address" "ingress_ip" {
  name = "ingress-static-ip"
  external_ipv4_address {
    zone_id = "ru-central1-a"
  }
}

resource "yandex_compute_instance" "bastion" {
  name                      = "bastion"
  platform_id               = "standard-v2"
  allow_stopping_for_update = true
  zone                      = "ru-central1-a"

  resources {
    cores  = var.bastion_cores
    memory = var.bastion_memory
  }

  boot_disk {
    initialize_params {
      image_id = var.bastion_image_id
      size     = 20
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.diplom_subnets["ru-central1-a"].id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.bastion_sg.id]
  }

  metadata = {
    user-data = local.bastion_cloud_init
    ssh-keys  = "ubuntu:${local.ssh_public_key}"
  }

  scheduling_policy {
    preemptible = true
  }
}

resource "yandex_compute_instance" "k8s_master" {
  name                      = "k8s-master"
  platform_id               = "standard-v2"
  allow_stopping_for_update = true
  zone                      = "ru-central1-a"

  resources {
    cores  = var.k8s_master_cores
    memory = var.k8s_master_memory
  }

  boot_disk {
    initialize_params {
      image_id = var.k8s_image_id
      size     = 40
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.diplom_subnets["ru-central1-a"].id
    nat                = false
    security_group_ids = [yandex_vpc_security_group.k8s_sg.id]
  }

  metadata = {
    user-data = local.k8s_cloud_init
    ssh-keys  = "ubuntu:${local.ssh_public_key}"
  }

  scheduling_policy {
    preemptible = false
  }
}

resource "yandex_compute_instance" "k8s_workers" {
  count                     = 2
  name                      = "k8s-worker-${count.index + 1}"
  platform_id               = "standard-v2"
  allow_stopping_for_update = true
  description               = "Kubernetes worker node ${count.index + 1}"
  zone                      = count.index == 0 ? "ru-central1-b" : "ru-central1-d"

  resources {
    cores  = var.k8s_worker_cores
    memory = var.k8s_worker_memory
  }

  boot_disk {
    initialize_params {
      image_id = var.k8s_image_id
      size     = 50
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.diplom_subnets[count.index == 0 ? "ru-central1-b" : "ru-central1-d"].id
    nat                = false
    security_group_ids = [yandex_vpc_security_group.k8s_sg.id]
  }

  metadata = {
    user-data = local.k8s_cloud_init
    ssh-keys  = "ubuntu:${local.ssh_public_key}"
  }

  scheduling_policy {
    preemptible = true
  }
}

data "yandex_client_config" "current" {}

resource "yandex_container_registry" "diplom_registry" {
  name      = "diplom-registry-luckyvl"
  folder_id = data.yandex_client_config.current.folder_id
}

output "registry_id" {
  description = "ID созданного Container Registry"
  value       = yandex_container_registry.diplom_registry.id
}