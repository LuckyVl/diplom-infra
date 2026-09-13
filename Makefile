# === INFRASTRUCTURE ===
infra-init:
	cd terraform/infra && terraform init -backend-config=backend.tfvars

infra-plan:
	cd terraform/infra && terraform plan

infra-apply:
	cd terraform/infra && terraform apply -auto-approve
	@echo "✅ Инфраструктура создана в облаке."
	@echo "⏳ Ждем 60 секунд, пока ВМ загрузятся и поднимут SSH-сервер..."
	@sleep 60
	@echo "🔄 Обновляем конфигурацию..."
	@mkdir -p ansible/inventory
	@terraform -chdir=terraform/infra output -raw ansible_inventory > ansible/inventory/hosts.ini
	@BASTION_IP=$$(terraform -chdir=terraform/infra output -raw bastion_public_ip); \
	echo "🔄 Обновляем ~/.ssh/config с новым IP: $$BASTION_IP"; \
	sed -i '/^Host bastion$$/,/^$$/d' ~/.ssh/config; \
	echo "" >> ~/.ssh/config; \
	echo "Host bastion" >> ~/.ssh/config; \
	echo "    HostName $$BASTION_IP" >> ~/.ssh/config; \
	echo "    User ubuntu" >> ~/.ssh/config; \
	echo "    IdentityFile /home/admin/.ssh/diplom_cloud" >> ~/.ssh/config; \
	echo "    StrictHostKeyChecking no" >> ~/.ssh/config; \
	echo "    IdentitiesOnly yes" >> ~/.ssh/config; \
	echo "✅ Ansible inventory и ~/.ssh/config успешно обновлены!"; \
	echo "🔗 IP бастиона: $$BASTION_IP"

infra-destroy:
	cd terraform/infra && terraform destroy -auto-approve

test:
	@echo "🧪 Запуск тестов инфраструктуры..."
	./test-infra.sh

infra-redeploy: infra-destroy infra-apply