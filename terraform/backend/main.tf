terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.120"
    }
  }
}

provider "yandex" {
  zone                     = "ru-central1-a"
  cloud_id                 = "b1goo5pkjq9ldvqkgp0l"
  folder_id                = "b1g7c66oo5q6sjc4bdlt"
  service_account_key_file = "/home/admin/.config/yandex-cloud/terraform-admin-key.json"
}

# Сервисный аккаунт
resource "yandex_iam_service_account" "terraform_sa" {
  name        = "terraform-sa"
  description = "Service account for Terraform infrastructure management"
  folder_id = var.folder_id
}

# Права сервисному аккаунту
resource "yandex_resourcemanager_folder_iam_member" "sa_editor" {
  folder_id = var.folder_id
  role      = "editor"
  member    = "serviceAccount:${yandex_iam_service_account.terraform_sa.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "sa_storage_admin" {
  folder_id = var.folder_id
  role      = "storage.admin"
  member    = "serviceAccount:${yandex_iam_service_account.terraform_sa.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "sa_compute_admin" {
  folder_id = var.folder_id
  role      = "compute.admin"
  member    = "serviceAccount:${yandex_iam_service_account.terraform_sa.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "sa_vpc_admin" {
  folder_id = var.folder_id
  role      = "vpc.admin"
  member    = "serviceAccount:${yandex_iam_service_account.terraform_sa.id}"
}

# Terraform создает статические ключи для этого аккаунта
resource "yandex_iam_service_account_static_access_key" "sa_static_key" {
  service_account_id = yandex_iam_service_account.terraform_sa.id
  description        = "Static access key for S3 backend"
  
  depends_on = [
    yandex_resourcemanager_folder_iam_member.sa_storage_admin
  ]
}

# S3 бакет
resource "yandex_storage_bucket" "terraform_state" {
  bucket     = var.bucket_name
  access_key = yandex_iam_service_account_static_access_key.sa_static_key.access_key
  secret_key = yandex_iam_service_account_static_access_key.sa_static_key.secret_key
  
  versioning {
    enabled = true
  }
  
  depends_on = [
    yandex_resourcemanager_folder_iam_member.sa_storage_admin
  ]
}