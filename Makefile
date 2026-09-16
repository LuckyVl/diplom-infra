# === ИНИЦИАЛИЗАЦИЯ ===
infra-init:
	cd terraform/infra && terraform init -backend-config=backend.tfvars

# === ПРОВЕРКА ===
infra-plan:
	cd terraform/infra && terraform plan

# === РАЗВОРАЧИВАНИЕ ИНФРАСТРУКТУРЫ  ===
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

# === УНИЧТОЖЕНИЕ ИНФРАСТРУКТУРЫ ===
infra-destroy:
	@echo "🧹 Очистка Container Registry перед удалением..."
	@REGISTRY_ID=$$(terraform -chdir=terraform/infra output -raw registry_id 2>/dev/null || echo ""); \
	if [ -n "$$REGISTRY_ID" ]; then \
		echo "Найден реестр: $$REGISTRY_ID. Удаляем образы..."; \
		yc container image list --registry-id $$REGISTRY_ID --format json 2>/dev/null | jq -r '.[].id' | while read image_id; do \
			if [ -n "$$image_id" ]; then \
				echo "  Удаляем образ: $$image_id"; \
				yc container image delete --id $$image_id --async 2>/dev/null || true; \
			fi \
		done; \
		echo "⏳ Ждем 10 секунд, пока облако обработает удаление образов..."; \
		sleep 10; \
	fi
	@echo "🔨 Запуск terraform destroy..."
	cd terraform/infra && terraform destroy -auto-approve

# === ТЕСТИРОВАНИЕ ИНФРАСТРУКТУРЫ ПОСЛЕ РАЗВОРАЧИВАНИЯ ===
test-infra:
	@echo "🧪 Запуск тестов инфраструктуры..."
	./scripts/test-infra.sh

# === ПЕРЕРАЗВОРАЧИВАНИЕ ИНФРАСТРУКТУРЫ ===
infra-redeploy: infra-destroy infra-apply

# === РАЗВОРАЧИВАНИЕ K8S ===
k8s-deploy:
	@echo "🚀 Запуск скрипта развертывания Kubernetes..."
	./scripts/deploy-k8s.sh

# === СБОРКА ОБРАЗА ПРИЛОЖЕНИЯ И ЗАГРУЗКА В REGISTRY ===
build-app:
	@echo " Сборка Docker образа..."
	@REGISTRY_ID=$$(terraform -chdir=terraform/infra output -raw registry_id); \
	cd ../diplom-app && docker build --no-cache -t cr.yandex/$$REGISTRY_ID/diplom-app:v1.0.0 .
	@echo "✅ Образ собран"

# === СБОРКА И ЗАГРУЗКА ОБРАЗА ПРИЛОЖЕНИЯ В REGISTRY ===
push-app: build-app
	@echo "📤 Загрузка образа в Yandex Container Registry..."
	@REGISTRY_ID=$$(terraform -chdir=terraform/infra output -raw registry_id); \
	docker push cr.yandex/$$REGISTRY_ID/diplom-app:v1.0.0
	@echo "✅ Образ загружен в registry"

# === СПИСОК ОБРАЗОВ В REGISTRY ===
list-images:
	@echo " Список образов в registry:"
	@REGISTRY_ID=$$(terraform -chdir=terraform/infra output -raw registry_id); \
	yc container image list --registry-id $$REGISTRY_ID

# === ОЧИСТКА КОНФИГУРАЦИЙ И ДАННЫХ В DOCKER НА ХОСТЕ ГДЕ ВЫПОЛНЯЕТСЯ СБОРКА ===
docker-clean:
	@echo "🧹 Полная очистка Docker от старых образов и кэша (критично для обхода бага с кэшированием ID реестра)..."
	-docker rmi $$(docker images -q) 2>/dev/null || true
	-docker image prune -a -f
	-docker system prune -a -f
	@echo "✅ Docker очищен"

# === РАЗВОРАЧИВАНИЕ INGRESS ===
deploy-ingress:
	@echo "🚀 Деплой Nginx Ingress Controller..."
	@IP=$$(terraform -chdir=terraform/infra output -raw ingress_static_ip); \
	sed "s/PLACEHOLDER_IP/$$IP/g" k8s-manifests/ingress/nginx-ingress-values.yaml > /tmp/nginx-values.yaml; \
	helm upgrade --install ingress-nginx ingress-nginx \
		--repo https://kubernetes.github.io/ingress-nginx \
		--namespace ingress-nginx --create-namespace \
		-f /tmp/nginx-values.yaml \
		--wait

# === РАЗВОРАЧИВАНИЕ PROMETHEUS ===
deploy-monitoring:
	@echo "📊 Деплой kube-prometheus-stack..."
	helm upgrade --install prometheus-stack prometheus-community/kube-prometheus-stack \
		--repo https://prometheus-community.github.io/helm-charts \
		--namespace monitoring --create-namespace \
		-f k8s-manifests/monitoring/prometheus-values.yaml \
		--wait

# === РАЗВОРАЧИВАНИЕ APP ===
deploy-app:
	@echo "📦 Деплой тестового приложения..."
	@REGISTRY_ID=$$(terraform -chdir=terraform/infra output -raw registry_id); \
	sed "s/PLACEHOLDER_REGISTRY_ID/$$REGISTRY_ID/g" k8s-manifests/app/deployment.yaml | kubectl apply -f -
	kubectl apply -f k8s-manifests/app/ingress.yaml

# === РАЗВОРАЧИВАНИЕ INGRESS + PROMETHEUS + APP ===
deploy-all-k8s: deploy-ingress deploy-monitoring deploy-app
	@echo "✅ Все K8s компоненты успешно задеплоены!"
	@echo "🔗 Получи IP Ingress командой: kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}'"

# === ПОЛНОЕ РАЗВЕРТЫВАНИЕ ===
deploy-all: infra-apply test-infra k8s-deploy push-app list-images deploy-all-k8s
	@echo "✅ ПОЛНОЕ РАЗВЕРТЫВАНИЕ ЗАВЕРШЕНО!"
	@echo "Инфраструктура создана"
	@echo "Kubernetes работает"
	@echo "Образ приложения собран"
	@echo "Образ загружен в registry"


# === ПОЛНОЕ УНИЧТОЖЕНИЕ ===
destroy-all: infra-destroy docker-clean
	@echo "🧹 Очистка локальных конфигураций..."
	@rm -f ~/.kube/config
	@echo "⚠️ ИНФРАСТРУКТУРА УНИЧТОЖЕНА"
	@echo "S3 backend и сервисный аккаунт сохранены."