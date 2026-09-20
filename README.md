# Дипломная работа по профессии "DevOps-инженер"
## Ресурсы
https://github.com/LuckyVl/diplom-infra - основной код инфраструктуры
https://github.com/LuckyVl/diplom-app - код тестового приложения и CI\CD
## Как реализовано
### Схема
```mermaid
graph TB
    subgraph "🖥️ Local Environment - Windows Host"
        Win["Windows 10/11"]
        VSCode["VS Code + Remote SSH"]
        GitWin["Git for Windows"]
    end
    
    subgraph "🐧 Ubuntu VM (diplom-vm)"
        Ubuntu["Ubuntu 22.04"]
        GitUbuntu["Git"]
        Ansible["Ansible (venv)"]
        Terraform["Terraform"]
        YC_CLI["Yandex Cloud CLI"]
        Kubectl["kubectl"]
        Helm["Helm"]
        DockerLocal["Docker"]
        SSHKeys["SSH Keys"]
    end
    
    subgraph "☁️ Yandex Cloud"
        subgraph "🌐 Zone: ru-central1-a"
            Bastion["Bastion Host<br/>Public: *.*.*.*/32<br/>Private: 10.50.0.*"]
            K8sMaster["K8s Master<br/>10.50.0.*"]
            SubnetA["Subnet 10.50.0.0/24"]
        end
        
        subgraph "🌐 Zone: ru-central1-b"
            Worker1["K8s Worker-1<br/>10.50.1.*"]
            SubnetB["Subnet 10.50.1.0/24"]
        end
        
        subgraph "🌐 Zone: ru-central1-d"
            Worker2["K8s Worker-2<br/>10.50.2.*"]
            SubnetD["Subnet 10.50.2.0/24"]
        end
        
        S3["S3 Bucket<br/>Terraform State"]
        Registry["Container Registry<br/>cr.yandex/..."]
        VPC["VPC Network<br/>10.50.0.0/16"]
        SG["Security Groups"]
        LB["Load Balancer<br/>Ingress Controller<br/>Public: *.*.*.*/32"]

        subgraph "🔒 Security Groups"
        BastionSG["bastion-sg<br/>Ingress: TCP 22 (my_ip)<br/>ICMP (10.50.0.0/16)<br/>Egress: ANY"]
        K8sSG["k8s-sg<br/>Ingress: TCP 22, 80, 443, 6443, 10250<br/>TCP 30000-32767<br/>ICMP, ANY (10.50.0.0/16)<br/>Egress: ANY"]
        end
    end
    
    subgraph " GitHub"
        GHInfra["Repo: diplom-infra"]
        GHApp["Repo: diplom-app"]
        GHActions["GitHub Actions"]
    end
    
    subgraph "⚙️ Kubernetes Cluster"
        Ingress["Nginx Ingress<br/>Port 80/443"]
        Grafana["Grafana<br/>Monitoring"]
        Prometheus["Prometheus"]
        App["Diplom App<br/>Nginx"]
    end
    
    subgraph "🌍 Published Services"
        GrafanaURL["Grafana"]
        AppURL["Test Application"]
    end
    
    %% Local connections
    Win -->|"Remote SSH"| VSCode
    VSCode -->|"Terminal"| Ubuntu
    GitWin -->|"SSH Keys"| Ubuntu
    
    %% Ubuntu VM internal
    Ubuntu --> GitUbuntu
    GitUbuntu -->|"Git Push/Pull"| GHInfra
    GitUbuntu -->|"Git Push/Pull"| GHApp
    
    %% VM to Cloud connections - ALL SSH goes through Bastion
    Ubuntu -->|"SSH ProxyJump via Bastion"| Bastion
    Bastion -->|"SSH to Master"| K8sMaster
    Bastion -->|"SSH to Worker-1"| Worker1
    Bastion -->|"SSH to Worker-2"| Worker2
    
    Ubuntu -->|"Terraform API"| VPC
    Ubuntu -->|"YC CLI API"| S3
    Ubuntu -->|"Docker Push"| Registry
    
    %% Network connections
    VPC --> SubnetA
    VPC --> SubnetB
    VPC --> SubnetD
    SubnetA --> Bastion
    SubnetA --> K8sMaster
    SubnetB --> Worker1
    SubnetD --> Worker2
    
    %% Security
    SG -.->|"SSH from Internet"| Bastion
    SG -.->|"SSH from Bastion only"| K8sMaster
    SG -.->|"SSH from Bastion only"| Worker1
    SG -.->|"SSH from Bastion only"| Worker2
    SG -.->|"Internal traffic"| K8sMaster
    SG -.->|"Internal traffic"| Worker1
    SG -.->|"Internal traffic"| Worker2
    SG -.->|"Traffic from Internet"| LB
    
    %% CI/CD Flow - also through Bastion
    GHInfra -->|"Webhook"| GHActions
    GHApp -->|"Webhook"| GHActions
    GHActions -->|"YC CLI Auth"| Registry
    GHActions -->|"SSH via Bastion"| Bastion
    Bastion -->|"Kubectl set image"| K8sMaster
    K8sMaster -->|"Kubectl apply"| App
    
    %% K8s Internal
    K8sMaster --> Ingress
    Worker1 --> Ingress
    Worker2 --> Ingress
    Ingress --> App
    Ingress --> Grafana
    
    %% Load Balancer to Ingress
    LB -->|"Routes traffic"| Ingress
    
    %% Published Services
    Ingress -->|"HTTP"| GrafanaURL
    Ingress -->|"HTTP"| AppURL
    
    %% Monitoring
    Grafana --> Prometheus
    Prometheus -->|"Metrics"| K8sMaster
    Prometheus -->|"Metrics"| Worker1
    Prometheus -->|"Metrics"| Worker2
    
    %% Styling
    classDef dark fill:#2d2d2d,stroke:#666,stroke-width:2px,color:#fff
    classDef darkBlue fill:#1e3a5f,stroke:#4a90e2,stroke-width:2px,color:#fff
    classDef darkGreen fill:#1e4d2e,stroke:#4caf50,stroke-width:2px,color:#fff
    classDef darkPurple fill:#3d1e5f,stroke:#9c27b0,stroke-width:2px,color:#fff
    classDef darkOrange fill:#5f3d1e,stroke:#ff9800,stroke-width:2px,color:#fff
    classDef darkRed fill:#5f1e1e,stroke:#f44336,stroke-width:2px,color:#fff
    classDef darkCyan fill:#1e5f5f,stroke:#00bcd4,stroke-width:2px,color:#fff
    classDef darkYellow fill:#5f5f1e,stroke:#ffeb3b,stroke-width:2px,color:#fff
    
    class Win,VSCode,GitWin,GitUbuntu,Ubuntu,Ansible,Terraform,YC_CLI,Kubectl,Helm,DockerLocal,SSHKeys dark
    class GHInfra,GHApp,GHActions darkBlue
    class Bastion,K8sMaster,Worker1,Worker2 darkGreen
    class SubnetA,SubnetB,SubnetD,VPC,SG darkOrange
    class S3,Registry darkPurple
    class Ingress,Grafana,Prometheus,App darkRed
    class LB darkCyan
    class GrafanaURL,AppURL darkYellow
```
### Инфраструктура как Код
```mermaid
sequenceDiagram
    participant Dev as Developer (You)
    participant VM as Ubuntu VM
    participant Git as GitHub
    participant TF as Terraform
    participant YC as Yandex Cloud
    
    Dev->>VM: Edit Terraform files
    VM->>Git: git push
    Git->>VM: git pull (on another session)
    VM->>TF: terraform init
    VM->>S3: Read state (backend.tfvars)
    S3-->>TF: Return state
    TF->>YC: terraform apply
    YC-->>TF: Create/Update resources
    TF->>S3: Save new state
    TF->>VM: Output IPs
    VM->>VM: Update ansible/inventory/hosts.ini
    VM->>VM: Update ~/.ssh/config
```

### Разворачивание K8S
```mermaid
sequenceDiagram
    participant VM as Ubuntu VM
    participant Ansible as Ansible
    participant K8s as K8s Cluster
    participant Helm as Helm
    
    VM->>VM: source ansible-venv/bin/activate
    VM->>Ansible: ansible-playbook cluster.yml
    Ansible->>K8s: SSH via Bastion
    K8s-->>Ansible: Install containerd, kubelet, etc.
    Ansible->>K8s: Initialize cluster (kubeadm)
    K8s-->>Ansible: Cluster ready
    VM->>VM: Copy kubeconfig
    VM->>Helm: helm install monitoring/ingress
    Helm->>K8s: Deploy pods
    K8s-->>Helm: Pods Running
```

### CI/CD
```mermaid
sequenceDiagram
    participant Dev as Developer
    participant GHApp as GitHub App Repo
    participant Actions as GitHub Actions
    participant Registry as YC Registry
    participant Bastion as Bastion Host
    participant K8s as K8s Master
    
    Dev->>GHApp: git commit & push
    GHApp->>Actions: Trigger workflow
    Actions->>Actions: Checkout code
    Actions->>Actions: Install YC CLI
    Actions->>Actions: Auth with SA Key
    Actions->>Registry: docker build & push
    Registry-->>Actions: Image uploaded
    
    alt Tag pushed (v*)
        Actions->>Bastion: SSH connect
        Bastion->>K8s: Proxy to master
        K8s->>K8s: kubectl set image
        K8s-->>Actions: Deployment updated
        Actions-->>Dev: Success notification
    end
```
## Как достигается полная автоматизация
### Backend (S3 + SA)
make backend-init        # terraform init
make backend-plan        # terraform plan
make backend-apply       # terraform apply

### Infrastructure
make infra-init          # terraform init
make infra-plan          # terraform plan
make infra-apply         # Созлдание инфраструктуры в облаке
make infra-destroy       # Уничтожение инфраструктуры в облаке
test-infra               # Тестирование инфраструктуры test-infra.sh
infra-redeploy           # Развертывания Kubernetes

### K8S
make k8s-deploy          # Развертывания Kubernetes 
make k8s-retry           # Повторный запуск развертывания Kubernetes на случай ошибок первого запуска
make k8s-reset           # Сброс конфигурации Kubernetes 
make k8s-retry-node1     # Повторный запуск настройки node1
make k8s-retry-node2     # Повторный запуск настройки node2
make k8s-retry-node3     # Повторный запуск настройки node3
make k8s-tunnel          # Настройка SSH-туннеля и kubeconfig к API-серверу Kubernetes
make registry-login      # Авторизация в Registry

### Application
make build-app           # docker build
make push-app            # docker push в Registry
make list-images         # Список образов в Registry
make docker-clean        # Сброс настроек и данных в docker на Ubuntu VM (diplom-vm)

### Service
make deploy-ingress      # Установка ingress-nginx в Kubernetes
make deploy-monitoring   # Установка kube-prometheus-stack в Kubernetes
make deploy-app          # Установка тестового приложения в Kubernetes
make deploy-all-k8s      # Все вышеперечисленное
make check-ingress       # Тестирование Ingress

### Master 
make deploy-all          # Бесшовное разворачивание от и до
make destroy-all              # Уничтожение текущей инфраструктуры и зачистка данных 

## Артефакты подтверждающие выполнение задач из дипломной работ
Часть артефактов собирается в процессе разворачивания (make deploy-all), а часть собирается после, чтобы показать бесшовность процеса.
### Инфраструктура
#### Backend (S3 + SA)
![alt text](./Img/image.png)
![alt text](./Img/image-2.png)
![alt text](./Img/image-1.png)
![alt text](./Img/image-3.png)
#### Infrastructure
Время запуска make deploy-all 18.09.2026 20:09 20:49
![alt text](./Img/image-12.png)
![alt text](./Img/image-13.png)
![alt text](./Img/image-14.png)
![alt text](./Img/image-15.png)
![alt text](./Img/image-16.png)
![alt text](./Img/image-17.png)
![alt text](./Img/image-18.png)
<details>
<summary>Артефакты установки kubespray (время установки 00:23:18, поправка времени на +03:00:00)</summary>
![alt text](./Img/image-19.png)
![alt text](./Img/image-20.png)
![alt text](./Img/image-21.png)
![alt text](./Img/image-22.png)
![alt text](./Img/image-23.png)
![alt text](./Img/image-24.png)
![alt text](./Img/image-25.png)
![alt text](./Img/image-26.png)
![alt text](./Img/image-27.png)
![alt text](./Img/image-28.png)
![alt text](./Img/image-29.png)
![alt text](./Img/image-30.png)
![alt text](./Img/image-31.png)
![alt text](./Img/image-32.png)
![alt text](./Img/image-33.png)
![alt text](./Img/image-34.png)
![alt text](./Img/image-35.png)
![alt text](./Img/image-36.png)
![alt text](./Img/image-37.png)
![alt text](./Img/image-38.png)
![alt text](./Img/image-39.png)
![alt text](./Img/image-40.png)
![alt text](./Img/image-41.png)
![alt text](./Img/image-42.png)
![alt text](./Img/image-43.png)
![alt text](./Img/image-44.png)
![alt text](./Img/image-45.png)
![alt text](./Img/image-46.png)
![alt text](./Img/image-47.png)
![alt text](./Img/image-48.png)
![alt text](./Img/image-49.png)
![alt text](./Img/image-50.png)
![alt text](./Img/image-51.png)
</details>

![alt text](./Img/image-52.png)
![alt text](./Img/image-54.png)
![alt text](./Img/image-55.png)
![alt text](./Img/image-56.png)
![alt text](./Img/image-57.png)
![alt text](./Img/image-58.png)
![alt text](./Img/image-61.png)
![alt text](./Img/image-62.png)
![alt text](./Img/image-65.png)
![alt text](./Img/image-66.png)
![alt text](./Img/image-59.png)
![alt text](./Img/image-60.png)
![alt text](./Img/image-64.png)
![alt text](./Img/image-63.png)
![alt text](./Img/image-67.png)
с убунту графана
![alt text](./Img/image-68.png)
![alt text](./Img/image-69.png)
с убунту прометеус
![alt text](./Img/image-70.png)
с убунту приложение
![alt text](./Img/image-72.png)
С териминала
![alt text](./Img/image-73.png)

c Wibdows ПК
![alt text](./Img/image-77.png)
![alt text](./Img/image-74.png)  
![alt text](./Img/image-75.png)  
![alt text](./Img/image-76.png) 

![alt text](./Img/image-78.png)
![alt text](./Img/image-79.png)
![alt text](./Img/image-80.png)
![alt text](./Img/image-81.png)
![alt text](./Img/image-82.png)
![alt text](./Img/image-83.png)

![alt text](./Img/image-84.png)
![alt text](./Img/image-85.png)
![alt text](./Img/image-86.png)
![alt text](./Img/image-87.png)
![alt text](./Img/image-88.png)
![alt text](./Img/image-89.png)
![alt text](./Img/image-90.png)
![alt text](./Img/image-91.png)
![alt text](./Img/image-92.png)

разбираем инфру
![alt text](./Img/image-93.png)
![alt text](./Img/image-94.png)
![alt text](./Img/image-95.png)
![alt text](./Img/image-96.png)
![alt text](./Img/image-97.png)
