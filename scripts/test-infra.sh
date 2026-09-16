#!/bin/bash
set -e

echo "=========================================="
echo "🧪 Infrastructure Validation Tests"
echo "=========================================="
echo ""

cd /home/admin/diplom/diplom-infra

echo "=== Test 1: DNS Resolution ==="
ansible k8s_cluster -i ansible/inventory/hosts.ini -m shell -a '
  nslookup mirror.yandex.ru > /dev/null 2>&1 && echo "✅ $(hostname) DNS OK" || echo "❌ $(hostname) DNS FAIL"
'
echo ""

echo "=== Test 2: Registry Access ==="
ansible k8s_cluster -i ansible/inventory/hosts.ini -m shell -a '
  curl -s --max-time 5 https://registry.k8s.io/v2/ > /dev/null && echo "✅ $(hostname) registry.k8s.io" || echo "❌ $(hostname) registry.k8s.io"
'
echo ""

echo "=== Test 3: Swap Status ==="
ansible k8s_cluster -i ansible/inventory/hosts.ini -m shell -a '
  swap_total=$(free -m | grep Swap | awk "{print \$2}")
  [ "$swap_total" = "0" ] && echo "✅ $(hostname) swap disabled" || echo "❌ $(hostname) swap enabled ($swap_total MB)"
'
echo ""

echo "=== Test 4: Python Version ==="
ansible k8s_cluster -i ansible/inventory/hosts.ini -m shell -a 'python3 --version'
echo ""

echo "=== Test 5: Check ICMP ping mesh between all nodes ==="
ansible all -i ansible/inventory/hosts.ini -f 1 -m shell -a '
for pair in {% for h in groups["all"] %}{{ h }}:{{ hostvars[h].ansible_host | default(h) }} {% endfor %}; do
  name=${pair%%:*}
  ip=${pair##*:}
  ping -c 1 -W 2 $ip > /dev/null 2>&1 && echo "✅ $(hostname) -> $name ($ip)" || echo "❌ $(hostname) -> $name ($ip)"
done'
echo ""

echo "=========================================="
echo "✅ All tests completed!"
echo "=========================================="
