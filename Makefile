# === INFRASTRUCTURE ===
infra-init:
	cd terraform/infra && terraform init -backend-config=backend.tfvars

infra-plan:
	cd terraform/infra && terraform plan

infra-apply:
	cd terraform/infra && terraform apply --auto-approve
	@echo "✅ Infrastructure applied. Updating Ansible inventory..."
	@mkdir -p ansible/inventory
	@terraform -chdir=terraform/infra output -raw ansible_inventory > ansible/inventory/hosts.ini
	@echo "✅ Ansible inventory updated successfully!"

infra-destroy:
	cd terraform/infra && terraform destroy --auto-approve

# обновление инвентаря (опция)
update-inventory:
	@echo "🔄 Updating Ansible inventory from Terraform outputs..."
	@mkdir -p ansible/inventory
	@terraform -chdir=terraform/infra output -raw ansible_inventory > ansible/inventory/hosts.ini
	@echo "✅ Done!"
