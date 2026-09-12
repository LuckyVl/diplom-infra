terraform {
  backend "s3" {
    endpoints = {
      s3 = "https://storage.yandexcloud.net"
    }
    
    bucket                    = "diplom-terraform-state-luckyvl"
    region                    = "ru-central1"
    key                       = "infra/terraform.tfstate"
    
    # Отключаем лишние проверки для Yandex Object Storage
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
  }

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