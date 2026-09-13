#!/bin/bash
set -e # Останавливать скрипт при любой ошибке

echo "🚀 Запуск автоматизированного развертывания Kubernetes..."

# 1. Получаем актуальные IP-адреса из Terraform
echo "📡 Чтение IP-адресов из Terraform state..."
cd ~/diplom/diplom-infra
MASTER_IP=$(terraform -chdir=terraform/infra output -raw k8s_master_internal_ip)
# Получаем массив IP воркеров
readarray -t WORKER_IPS < <(terraform -chdir=terraform/infra output -json k8s_workers_internal_ips | jq -r '.[]')

# Объединяем в один массив (Мастер всегда первый)
IPS=("$MASTER_IP" "${WORKER_IPS[@]}")
echo "✅ Найденные ноды: ${IPS[*]}"

# 2. Подготовка окружения Kubespray
KS_DIR="$HOME/diplom/kubespray-temp/kubespray"
if [ ! -d "$KS_DIR" ]; then
    echo "⬇️ Клонирование Kubespray v2.25.0..."
    mkdir -p ~/diplom/kubespray-temp
    cd ~/diplom/kubespray-temp
    git clone -b v2.25.0 https://github.com/kubernetes-sigs/kubespray.git
    cd kubespray
    source ~/ansible-venv/bin/activate
    pip install -q -r requirements.txt
else
    echo "✅ Директория Kubespray найдена, обновление зависимостей..."
    cd "$KS_DIR"
    source ~/ansible-venv/bin/activate
    pip install -q -r requirements.txt
fi

# 3. Генерация инвентаря
echo "📝 Генерация инвентаря Kubespray..."
rm -rf inventory/diplom
cp -rfp inventory/sample inventory/diplom
CONFIG_FILE=inventory/diplom/hosts.yaml python3 contrib/inventory_builder/inventory.py "${IPS[@]}"

# 4. Применение наших кастомных настроек (идемпотентно)
echo "⚙️ Применение оптимизированных настроек для Yandex Cloud..."

# Исправляем cloud_provider на external (наше главное исправление)
sed -i 's/^cloud_provider:.*/cloud_provider: external/' inventory/diplom/group_vars/all/all.yml

# Добавляем настройки, если их еще нет
grep -q "ansible_user: ubuntu" inventory/diplom/group_vars/all/all.yml || echo -e "\nansible_user: ubuntu\nansible_become: true\nansible_become_method: sudo\nkube_allow_privileged_containers: true" >> inventory/diplom/group_vars/all/all.yml

grep -q "kube_version: v1.29.5" inventory/diplom/group_vars/k8s_cluster/k8s-cluster.yml || echo -e "\nkube_version: v1.29.5\ningress_nginx_enabled: false\nmetrics_server_enabled: false\ncontainer_manager: containerd" >> inventory/diplom/group_vars/k8s_cluster/k8s-cluster.yml

# 5. Запуск Ansible
echo "🔨 Запуск Kubespray playbook (это займет 15-25 минут)..."
ansible-playbook -i inventory/diplom/hosts.yaml --become --become-user=root cluster.yml

# 6. Получение kubeconfig
echo "🔑 Настройка локального доступа (kubeconfig)..."
mkdir -p ~/.kube
ssh -o ProxyJump=bastion ubuntu@$MASTER_IP "sudo cat /etc/kubernetes/admin.conf" > ~/.kube/config
chmod 600 ~/.kube/config
# Заменяем localhost на реальный IP мастера для работы с твоей VM
sed -i "s/127.0.0.1/$MASTER_IP/g" ~/.kube/config

echo "🎉 Kubernetes успешно развернут и настроен!"
kubectl get nodes
