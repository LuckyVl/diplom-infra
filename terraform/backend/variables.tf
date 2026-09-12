variable "folder_id" {
  description = "Yandex Cloud Folder ID"
  type        = string
}

variable "bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  type        = string
  default     = "diplom-terraform-state-luckyvl"
}
