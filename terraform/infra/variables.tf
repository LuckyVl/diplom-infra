variable "vpc_name" {
  type    = string
  default = "diplom-vpc"
}

variable "subnet_cidrs" {
  type = map(string)
  default = {
    "ru-central1-a" = "10.10.0.0/24"
    "ru-central1-b" = "10.10.1.0/24"
    "ru-central1-d" = "10.10.2.0/24"
  }
}

# Актуальный ID Ubuntu 22.04 LTS из твоего вывода
variable "bastion_image_id" {
  type    = string
  default = "fd806c8slu9j1pa87msc"
}

variable "k8s_image_id" {
  type    = string
  default = "fd806c8slu9j1pa87msc"
}

variable "bastion_cores" {
  type    = number
  default = 2
}

variable "bastion_memory" {
  type    = number
  default = 2
}

# Увеличенные ресурсы для стабильной работы etcd и API server
variable "k8s_master_cores" {
  type    = number
  default = 4
}

variable "k8s_master_memory" {
  type    = number
  default = 8
}

# Увеличенные ресурсы для размещения Prometheus, Grafana и приложений
variable "k8s_worker_cores" {
  type    = number
  default = 4
}

variable "k8s_worker_memory" {
  type    = number
  default = 8
}

variable "ssh_public_key_path" {
  type    = string
  default = "/home/admin/.ssh/diploma_cloud.pub"
}

variable "my_ip" {
  type    = string
  default = "0.0.0.0/0" # Замени на свой реальный IP в terraform.tfvars
}