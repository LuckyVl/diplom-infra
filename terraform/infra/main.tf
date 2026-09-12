# Временный файл для проверки подключения к S3 backend
# Позже здесь будет описание VPC, подсетей и ВМ

data "yandex_client_config" "current" {}

output "current_folder_id" {
  value = data.yandex_client_config.current.folder_id
}
