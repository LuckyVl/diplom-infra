#!/bin/bash
set -e

echo "=========================================="
echo "🧪 Infrastructure Validation Tests"
echo "=========================================="
echo ""

cd /home/admin/diplom/diplom-infra

echo "=== Test 1: Internal Connectivity ==="
ansible k8s_cluster -i ansible/inventory/hosts.ini -m shell -a '
  ping -c 1 -W 2 10.50.0.5 > /dev/null 2>&1 && echo "✅ $(hostname) -> master" || echo "❌ $(hostname) -> master"
  ping -c 1 -W 2 10.50.1.16 > /dev/null 2>&1 && echo "✅ $(hostname) -> worker-1" || echo "❌ $(hostname) -> worker-1"
  ping -c 1 -W 2 10.50.2.8 > /dev/null 2>&1 && echo "✅ $(hostname) -> worker-2" || echo "❌ $(hostname) -> worker-2"
'
echo ""

echo "=== Test 2: DNS Resolution ==="
ansible k8s_cluster -i ansible/inventory/hosts.ini -m shell -a '
  nslookup mirror.yandex.ru > /dev/null 2>&1 && echo "✅ $(hostname) DNS OK" || echo "❌ $(hostname) DNS FAIL"
'
echo ""

echo "=== Test 3: Registry Access ==="
ansible k8s_cluster -i ansible/inventory/hosts.ini -m shell -a '
  curl -s --max-time 5 https://registry.k8s.io/v2/ > /dev/null && echo "✅ $(hostname) registry.k8s.io" || echo "❌ $(hostname) registry.k8s.io"
'
echo ""

echo "=== Test 4: Swap Status ==="
ansible k8s_cluster -i ansible/inventory/hosts.ini -m shell -a '
  swap_total=$(free -m | grep Swap | awk "{print \$2}")
  [ "$swap_total" = "0" ] && echo "✅ $(hostname) swap disabled" || echo "❌ $(hostname) swap enabled ($swap_total MB)"
'
echo ""

echo "=== Test 5: Python Version ==="
ansible k8s_cluster -i ansible/inventory/hosts.ini -m shell -a 'python3 --version'
echo ""

echo "=== Test 6: Security Isolation ==="
timeout 5 ssh ubuntu@10.50.0.5 "echo test" 2>&1 | grep -q "timed out\|refused" && echo "✅ K8s nodes isolated (secure)" || echo "❌ SECURITY ISSUE"
echo ""

echo "=========================================="
echo "✅ All tests completed!"
echo "=========================================="
