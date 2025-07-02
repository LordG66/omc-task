# ☁️ K3s-on-Proxmox Stack

This repository contains a fully automated solution for provisioning a secure, modular K3s cluster using Proxmox, Ansible, and Helm — complete with Jenkins and the Elastic Stack.

---

## 📦 Project Structure

```text
.
├── bootstrap.sh                # Interactive provisioning script
├── kubeconfig                  # Pulled after K3s deployment
├── k3s-ansible/                # Ansible roles and playbooks for K3s
├── kubernetes/
│   ├── charts/                 # Helm charts for ECK & Jenkins
│   ├── values/                 # Helm values per environment
│   |── deploy/                 # Kubernetes manifests (YAML)
|   |__ network-policies/       # Network Policies
├── terraform/                  # Proxmox VM provisioning
```

> SSH keys are excluded from this structure for security reasons.

---

## 🚀 How to Build the Project

1. Ensure you have:
   - A working **Proxmox environment** with:
     - Valid API credentials
     - An Ubuntu **cloud-init image** template pre-imported (e.g., `ubuntu-24.04-ci-template`)
   - SSH key pair for VM access
   - Local tools: `terraform`, `ansible`, `helm`, `kubectl`, `jq`, `yq`, `scp`

2. Run the bootstrap:

```bash
sh bootstrap.sh
```

This script:
- Provisions master + worker nodes on Proxmox via Terraform
- Configures them into a K3s cluster using Ansible
- Pulls and rewrites the kubeconfig for access
- Installs:
  - ECK (ElasticSearch, Kibana, Logstash)
  - Jenkins via Helm
  - All namespaces and network policies

3. 🔁 Update your DNS:
   - After deployment, point your DNS records (for Kibana, Jenkins, etc.) to the **IP address of the worker node(s)**.
   - These IPs are DHCP-assigned and can be found in the Terraform outputs or the Ansible inventory file.

---

## 🧼 Cleanup

```bash
terraform -chdir=terraform destroy
kubectl delete ns jenkins jenkins-cloud elastic-stack
```

---

## 🪪 Licensing

MIT — Feel free to use, modify, and contribute.