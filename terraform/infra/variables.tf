variable "vpc_name" {
  type    = string
  default = "diplom-vpc"
}

variable "subnet_cidrs" {
  type = map(string)
  default = {
    "ru-central1-a" = "10.50.0.0/24"
    "ru-central1-b" = "10.50.1.0/24"
    "ru-central1-d" = "10.50.2.0/24"
  }
}

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

variable "k8s_master_cores" {
  type    = number
  default = 4
}

variable "k8s_master_memory" {
  type    = number
  default = 8
}

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
  default = "/home/admin/.ssh/diplom_cloud.pub"
}

variable "my_ip" {
  type    = string
  default = "0.0.0.0/0"
}