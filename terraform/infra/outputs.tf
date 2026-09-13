output "bastion_public_ip" {
  value = yandex_compute_instance.bastion.network_interface[0].nat_ip_address
}

output "bastion_internal_ip" {
  value = yandex_compute_instance.bastion.network_interface[0].ip_address
}

output "k8s_master_internal_ip" {
  value = yandex_compute_instance.k8s_master.network_interface[0].ip_address
}

output "k8s_workers_internal_ips" {
  value = yandex_compute_instance.k8s_workers[*].network_interface[0].ip_address
}

output "ingress_static_ip" {
  value = yandex_vpc_address.ingress_ip.external_ipv4_address[0].address
}

output "vpc_id" {
  value = yandex_vpc_network.diplom_vpc.id
}

output "subnet_ids" {
  value = {
    for zone, subnet in yandex_vpc_subnet.diplom_subnets :
    zone => subnet.id
  }
}

   output "ansible_inventory" {
     value = <<-EOT
       [bastion]
       bastion-host ansible_host=${yandex_compute_instance.bastion.network_interface[0].nat_ip_address} ansible_user=ubuntu ansible_ssh_private_key_file=/home/admin/.ssh/diplom_cloud ansible_ssh_common_args='-o StrictHostKeyChecking=no -o IdentitiesOnly=yes'

       [master]
       k8s-master ansible_host=${yandex_compute_instance.k8s_master.network_interface[0].ip_address}

       [workers]
       k8s-worker-1 ansible_host=${yandex_compute_instance.k8s_workers[0].network_interface[0].ip_address}
       k8s-worker-2 ansible_host=${yandex_compute_instance.k8s_workers[1].network_interface[0].ip_address}

       [k8s_cluster:children]
       master
       workers

       [master:vars]
       ansible_user=ubuntu
       ansible_ssh_private_key_file=/home/admin/.ssh/diplom_cloud
       ansible_ssh_common_args='-o StrictHostKeyChecking=no -o IdentitiesOnly=yes -o ProxyJump=bastion'

       [workers:vars]
       ansible_user=ubuntu
       ansible_ssh_private_key_file=/home/admin/.ssh/diplom_cloud
       ansible_ssh_common_args='-o StrictHostKeyChecking=no -o IdentitiesOnly=yes -o ProxyJump=bastion'
     EOT
   }