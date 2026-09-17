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

# Повторный запуск Kubespray (если упал)
k8s-retry:
	@echo "🔄 Повторный запуск Kubespray (продолжение с места ошибки)..."
	cd ~/diplom/kubespray-temp/kubespray && \
	ansible-playbook -i inventory/diplom/hosts.yaml \
		--become --become-user=root \
		-e "ansible_user=ubuntu" \
		-e "ansible_ssh_private_key_file=/home/admin/.ssh/diplom_cloud" \
		-e "ansible_ssh_common_args='-o StrictHostKeyChecking=no -o ProxyJump=bastion'" \
		cluster.yml

# Полный сброс и переустановка K8s (если всё сломалось)
k8s-reset:
	@echo "⚠️ Полный сброс Kubernetes кластера..."
	cd ~/diplom/kubespray-temp/kubespray && \
	ansible-playbook -i inventory/diplom/hosts.yaml \
		--become --become-user=root \
		-e "ansible_user=ubuntu" \
		-e "ansible_ssh_private_key_file=/home/admin/.ssh/diplom_cloud" \
		-e "ansible_ssh_common_args='-o StrictHostKeyChecking=no -o ProxyJump=bastion'" \
		reset.yml
	@echo "✅ Сброс выполнен. Теперь запусти make k8s-deploy"

k8s-retry-node1:
	@echo "🔄 Перезапуск только на node1..."
	cd ~/diplom/kubespray-temp/kubespray && \
	ansible-playbook -i inventory/diplom/hosts.yaml \
		--become --become-user=root \
		--limit node1 \
		-e "ansible_user=ubuntu" \
		-e "ansible_ssh_private_key_file=/home/admin/.ssh/diplom_cloud" \
		-e "ansible_ssh_common_args='-o StrictHostKeyChecking=no -o ProxyJump=bastion'" \
		cluster.yml

k8s-retry-node2:
	@echo "🔄 Перезапуск только на node2..."
	cd ~/diplom/kubespray-temp/kubespray && \
	ansible-playbook -i inventory/diplom/hosts.yaml \
		--become --become-user=root \
		--limit node2 \
		-e "ansible_user=ubuntu" \
		-e "ansible_ssh_private_key_file=/home/admin/.ssh/diplom_cloud" \
		-e "ansible_ssh_common_args='-o StrictHostKeyChecking=no -o ProxyJump=bastion'" \
		cluster.yml

k8s-retry-node3:
	@echo "🔄 Перезапуск только на node3..."
	cd ~/diplom/kubespray-temp/kubespray && \
	ansible-playbook -i inventory/diplom/hosts.yaml \
		--become --become-user=root \
		--limit node3 \
		-e "ansible_user=ubuntu" \
		-e "ansible_ssh_private_key_file=/home/admin/.ssh/diplom_cloud" \
		-e "ansible_ssh_common_args='-o StrictHostKeyChecking=no -o ProxyJump=bastion'" \
		cluster.yml

# === РУЧНОЕ УПРАВЛЕНИЕ SSH-ТУННЕЛЕМ НА СЛУЧАЙ ОШИБКИ ПРИ РАЗВОРАЧИВАНИИ K8S ПОСЛЕ РУЧНОЙ ПОЧИНКИ K8S ===
k8s-tunnel:
k8s-tunnel:
	@echo "🚀 Настройка SSH-туннеля и kubeconfig к API-серверу Kubernetes..."
	@MASTER_IP=$$(terraform -chdir=terraform/infra output -raw k8s_master_internal_ip); \
	echo "📡 Найден Master IP: $$MASTER_IP"; \
	echo "📥 Получение kubeconfig с мастер-ноды..."; \
	mkdir -p ~/.kube; \
	ssh -o ProxyJump=bastion \
		-o StrictHostKeyChecking=no \
		-o IdentitiesOnly=yes \
		-i /home/admin/.ssh/diplom_cloud \
		ubuntu@$$MASTER_IP "sudo cat /etc/kubernetes/admin.conf" > ~/.kube/config; \
	chmod 600 ~/.kube/config; \
	sed -i "s|server: https://.*:6443|server: https://127.0.0.1:6443|g" ~/.kube/config; \
	echo "🧹 Очистка старых зависших туннелей на порту 6443..."; \
	pkill -f "ssh.*6443.*$$MASTER_IP" 2>/dev/null || true; \
	sleep 1; \
	echo "🔌 Создание нового туннеля: localhost:6443 -> $$MASTER_IP:6443 (через бастион)..."; \
	ssh -f -N -L 6443:$$MASTER_IP:6443 \
		-o ProxyJump=bastion \
		-o StrictHostKeyChecking=no \
		-o IdentitiesOnly=yes \
		-i /home/admin/.ssh/diplom_cloud \
		ubuntu@$$MASTER_IP; \
	echo "✅ Туннель и kubeconfig успешно настроены!"; \
	echo "🧪 Проверка подключения..."
	@kubectl get nodes

# === АВТОРИЗАЦИЯ В REGISTRY ===
registry-login:
	@echo "🔐 Принудительная очистка конфига Docker и авторизация через IAM-токен..."
	@rm -f ~/.docker/config.json
	@TOKEN=$$(yc iam create-token); \
	echo "$$TOKEN" | docker login --username iam --password-stdin cr.yandex
	@echo "✅ Авторизация успешна"

# === СБОРКА ОБРАЗА ПРИЛОЖЕНИЯ И ЗАГРУЗКА В REGISTRY ===
build-app:
	@echo " Сборка Docker образа..."
	@REGISTRY_ID=$$(terraform -chdir=terraform/infra output -raw registry_id); \
	cd ../diplom-app && docker build --no-cache -t cr.yandex/$$REGISTRY_ID/diplom-app:v1.0.0 .
	@echo "✅ Образ собран"

# === СБОРКА И ЗАГРУЗКА ОБРАЗА ПРИЛОЖЕНИЯ В REGISTRY ===
push-app: registry-login build-app
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
	@echo "🚀 Деплой Nginx Ingress Controller (режим hostNetwork)..."
	@helm upgrade --install ingress-nginx ingress-nginx \
		--repo https://kubernetes.github.io/ingress-nginx \
		--namespace ingress-nginx --create-namespace \
		--set controller.hostNetwork=true \
		--set controller.kind=DaemonSet \
		--set controller.service.type=ClusterIP \
		--timeout 10m0s \
		--wait
	@echo "✅ Ingress Controller успешно установлен!"
	@kubectl get pods -n ingress-nginx

# === ПРОВЕРКА СТАТУСА INGRESS ===
check-ingress:
	@echo "📊 Статус Ingress Controller:"
	@kubectl get pods -n ingress-nginx
	@echo ""
	@echo "🌐 Статус сервиса (EXTERNAL-IP):"
	@kubectl get svc -n ingress-nginx ingress-nginx-controller
	@echo ""
	@echo " Ingress ресурсы:"
	@kubectl get ingress --all-namespaces

# === РАЗВОРАЧИВАНИЕ PROMETHEUS ===
deploy-monitoring:
	@echo "📊 Подготовка Helm репозитория Prometheus..."
	@helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
	@helm repo update
	@echo "📊 Деплой kube-prometheus-stack..."
	helm upgrade --install prometheus-stack prometheus-community/kube-prometheus-stack \
		--namespace monitoring --create-namespace \
		-f k8s-manifests/monitoring/prometheus-values.yaml \
		--timeout 15m0s \
		--wait
	@echo "✅ Мониторинг успешно установлен!"
	@kubectl get pods -n monitoring

# === РАЗВОРАЧИВАНИЕ APP ===
# === РАЗВОРАЧИВАНИЕ APP ===
deploy-app:
	@echo " Деплой тестового приложения..."
	@echo "🔐 Создание секрета для доступа к Yandex Container Registry..."
	@TOKEN=$$(yc iam create-token); \
	kubectl delete secret yc-registry-secret --namespace=default --ignore-not-found; \
	kubectl create secret docker-registry yc-registry-secret \
		--docker-server=cr.yandex \
		--docker-username=iam \
		--docker-password="$$TOKEN" \
		--namespace=default
	@echo "📄 Применение конфигурации приложения..."
	@REGISTRY_ID=$$(terraform -chdir=terraform/infra output -raw registry_id); \
	sed "s/PLACEHOLDER_REGISTRY_ID/$$REGISTRY_ID/g" k8s-manifests/app/deployment.yaml | kubectl apply -f -
	@kubectl apply -f k8s-manifests/app/ingress.yaml
	@echo "✅ Приложение развернуто!"
	@kubectl get pods -n default -l app=diplom-app -w

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
	@rm -f ~/.ssh/known_hosts ~/.ssh/known_hosts2
	@echo "⚠️ ИНФРАСТРУКТУРА УНИЧТОЖЕНА"
	@echo "S3 backend и сервисный аккаунт сохранены."