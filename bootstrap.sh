#!/usr/bin/env bash
set -euo pipefail

#--------------------------------------------------------------------
# Prereqs (abort early if missing)
#--------------------------------------------------------------------
for bin in terraform jq openssl kubectl helm ssh scp yq; do
  command -v "$bin" >/dev/null 2>&1 || {
    echo >&2 "$bin is required but not installed. Aborting."
    exit 1
  }
done

#--------------------------------------------------------------------
# 1. Interactive prompts ➜ terraform.tfvars
#--------------------------------------------------------------------
cat <<'BANNER'
╔═══════════════════════════════════════════════════════════════════╗
║    Interactive Terraform / K3s / ECK / Jenkins bootstrap script  ║
╚═══════════════════════════════════════════════════════════════════╝
BANNER

read -rp "Proxmox API URL [https://proxmox-ip:8006/api2/json]: " prox_url
prox_url=${prox_url:-https://192.168.1.1:8006/api2/json}

read -rp "Proxmox user [terraform@pve]: " prox_user
prox_user=${prox_user:-terraform@pve}

read -rsp "Proxmox password [hidden]: " prox_pass; echo
prox_pass=${prox_pass:-password}

read -rp "Proxmox node [proxds01]: " prox_node
prox_node=${prox_node:-node-name}

read -rp "Template name [ubuntu-24.04-ci-template]: " template
template=${template:-ubuntu-24.04-ci-template}

read -rp "VM storage pool [local-ssd]: " vm_storage
vm_storage=${vm_storage:-local-ssd}

read -rp "Cloud-init user [root]: " ci_user
ci_user=${ci_user:-root}

read -rsp "Cloud-init password [hidden]: " ci_pass; echo
ci_pass=${ci_pass:-password}

read -rp "Path to your SSH public key [~/.ssh/id_ed25519.pub]: " pubkey
pubkey=${pubkey:-/Users/gabit/git/omc-task/id_ed25519.pub}
ci_key=$(cat "${pubkey}")

read -rp "Master count [1]: " master_cnt
master_cnt=${master_cnt:-1}

read -rp "Worker count [1]: " worker_cnt
worker_cnt=${worker_cnt:-1}

cat > terraform/terraform.tfvars <<EOF
proxmox_api_url   = "${prox_url}"
proxmox_user      = "${prox_user}"
proxmox_password  = "${prox_pass}"
node              = "${prox_node}"
template          = "${template}"
vm_storage        = "${vm_storage}"
ciuser            = "${ci_user}"
cipassword        = "${ci_pass}"
ci_ssh_keys       = "${ci_key}"
master_count      = ${master_cnt}
worker_count      = ${worker_cnt}
EOF
echo "terraform.tfvars written."

#--------------------------------------------------------------------
# 2. Apply Terraform
#--------------------------------------------------------------------
pushd terraform >/dev/null
echo "Running terraform init ..."
terraform init -upgrade -input=false
echo "Running terraform apply ..."
terraform apply -auto-approve
echo "Terraform finished."
echo "Sleeping for 2 minutes until agents are ready ..."
sleep 120
echo "Reapplying terraform state to pull IPs"
terraform apply -auto-approve
tf_json=$(terraform output -json)
popd >/dev/null

#--------------------------------------------------------------------
# 3. Build k3s-ansible inventory with IPs + random token
#--------------------------------------------------------------------
master_ips=$(echo "$tf_json" | jq -r '.master_ips.value[]')
worker_ips=$(echo "$tf_json" | jq -r '.worker_ips.value[]')

# pick the first master as API endpoint
first_master_ip=$(echo "$master_ips" | head -n1)

k3s_token=$(openssl rand -base64 64 | tr -d '\n')

inventory_path="k3s-ansible/inventory.yml"
cat > "$inventory_path" <<EOF
k3s_cluster:
  children:
    server:
      hosts:
$(for ip in $master_ips; do echo "        ${ip}:"; done)
    agent:
      hosts:
$(for ip in $worker_ips; do echo "        ${ip}:"; done)
  vars:
    ansible_port: 22
    ansible_user: ${ci_user}
    k3s_version: v1.30.2+k3s1
    ansible_ssh_private_key_file: $(dirname "$pubkey")/$(basename "$pubkey" .pub)
    host_key_checking: False
    token: "${k3s_token}"
    api_endpoint: "{{ hostvars[groups['server'][0]]['ansible_host'] | default(groups['server'][0]) }}"
EOF
echo "Inventory written to ${inventory_path}"

#--------------------------------------------------------------------
# 4. Run Ansible to provision K3s cluster
#--------------------------------------------------------------------
pushd k3s-ansible >/dev/null
echo "🚀 Running Ansible playbook to provision K3s ..."
ansible-playbook -i inventory.yml playbooks/site.yml
popd >/dev/null

#--------------------------------------------------------------------
# 5. Pull kubeconfig from first master & fix server IP
#--------------------------------------------------------------------
echo "Pulling kubeconfig from ${first_master_ip} ..."
scp -o StrictHostKeyChecking=no \
    -i "$(dirname "$pubkey")/$(basename "$pubkey" .pub)" \
    "${ci_user}@${first_master_ip}:/etc/rancher/k3s/k3s.yaml" ./kubeconfig

sed -i.bak "s#server: .*#server: https://${first_master_ip}:6443#g" kubeconfig
export KUBECONFIG=$PWD/kubeconfig
echo "kubeconfig ready at ./kubeconfig and KUBECONFIG exported."

#--------------------------------------------------------------------
# 5. Deploy namespaces, ECK, and Jenkins
#--------------------------------------------------------------------
echo "Applying base namespaces ..."
kubectl apply -f kubernetes/deploy/namespaces

echo "Installing ECK operator chart ..."
helm upgrade --install eck-operator \
  kubernetes/charts/eck-operator \
  -f kubernetes/values/eck-values.yaml \
  -n elastic-stack --create-namespace
sleep 60
echo "Applying ECK stack YAMLs ..."
kubectl apply -f kubernetes/deploy/eck-stack -n elastic-stack

echo "Installing Jenkins chart ..."
helm upgrade --install jenkins \
  kubernetes/charts/jenkins \
  -f kubernetes/values/jenkins-values.yaml \
  -n jenkins --create-namespace
sleep 60
echo "Applying Jenkins Job YAML ..."
kubectl apply -f kubernetes/deploy/jenkins-jobs -n jenkins

echo "Applying Network Policies"
kubectl apply -f kubernetes/deploy/network-policies

#--------------------------------------------------------------------
# 6. Output Access Information for Jenkins and Kibana
#--------------------------------------------------------------------

echo ""
echo "Gathering access information..."

# Jenkins
jenkins_url=$(kubectl get ingress jenkins -n jenkins -o jsonpath='{.spec.rules[0].host}')
jenkins_user=$(kubectl get secret jenkins -n jenkins -o jsonpath='{.data.jenkins-admin-user}' | base64 -d)
jenkins_pass=$(kubectl get secret jenkins -n jenkins -o jsonpath='{.data.jenkins-admin-password}' | base64 -d)

# Kibana
kibana_url=$(kubectl get ingress kibana-ingress -n elastic-stack -o jsonpath='{.spec.rules[0].host}')
kibana_user="elastic"
kibana_pass=$(kubectl get secret elasticsearch-es-elastic-user -n elastic-stack -o jsonpath='{.data.elastic}' | base64 -d)

echo ""
echo "🚀 Deployment Complete!"
echo ""
echo "🔧 Jenkins:"
echo "   URL:      http://${jenkins_url}"
echo "   Username: ${jenkins_user}"
echo "   Password: ${jenkins_pass}"
echo ""
echo "📊 Kibana:"
echo "   URL:      http://${kibana_url}"
echo "   Username: ${kibana_user}"
echo "   Password: ${kibana_pass}"
echo ""
