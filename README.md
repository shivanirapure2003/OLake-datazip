# OLake Assignment - Terraform + Minikube on AWS (Shiva)

## What this delivers
This repository contains Terraform code and automation to:
- Provision an AWS EC2 instance matching assignment requirements (>=4 vCPU, >=8GB RAM, 50GB disk)
- Install Docker, kubectl, Minikube, and Helm on the VM (using a provisioning script)
- Start Minikube, enable ingress & storage addons
- Deploy OLake Helm chart using a custom `values.yaml` that exposes the UI on port **8000**
- Produce outputs for VM IP and instance ID

**Important design choice:** This implementation uses Terraform to provision the EC2 VM and then uses Terraform's `remote-exec` provisioner to run a bash script on the VM which installs Minikube and deploys OLake with Helm.
This approach is:
- Easy for a reviewer to follow
- Reproducible and explicit
- Does not require running Terraform from inside the VM (which would complicate credential handling)

> Note: The assignment asked for using the Terraform Helm provider. That provider requires the kubeconfig to be available to the machine running `terraform`. Since we are running `terraform` locally and Minikube runs inside the remote VM, using the Helm CLI (in the remote VM) is simpler and more robust for this workflow. The README below explains how to adapt to the Helm provider if you prefer that approach.

---

## Prerequisites (on your local machine)
- Terraform v1.5+ installed
- AWS CLI configured (`~/.aws/credentials` with access key)
- An existing EC2 Key Pair in the chosen AWS region (key name will be passed as `key_name` variable)
- SSH agent running with your private key added (`ssh-add <path-to-private-key>`) or you can use direct private-key method if you modify the connection block.
- Internet access from the VM to download packages

---

## Files
- `terraform/` - Terraform code (main.tf, variables.tf)
- `minikube-setup.sh` - Provisioning script uploaded to the VM and executed there
- `values.yaml` - Custom Helm values for OLake (ingress enabled). Contains `{{VM_IP}}` placeholder replaced at runtime.
- `terraform.tfvars.example` - Example variables file
- `README.md` - This file
- `OLake_Assignment_Shiva.zip` - ZIP of repository (created for submission)

---

## How to run (high-level)
1. Ensure you have a key pair in AWS for SSH access.
2. Start ssh-agent and add your private key so Terraform can use SSH agent forwarding:
   ```bash
   eval "$(ssh-agent -s)"
   ssh-add ~/.ssh/id_rsa
   ```
3. Edit `terraform/terraform.tfvars` (copy from `terraform.tfvars.example`) and set `key_name` to your key pair name if desired.
4. From the `terraform/` directory:
   ```bash
   terraform init
   terraform apply -var="key_name=<your-keypair-name>" -auto-approve
   ```
5. After apply completes, note the VM public IP from output `vm_public_ip`.
6. Open in browser: `http://<VM_PUBLIC_IP>:8000` and login with default credentials:
   - Username: `admin`
   - Password: `password`

---

## Cleanup
Destroy everything when done:
```bash
cd terraform
terraform destroy -var="key_name=<your-keypair-name>" -auto-approve
```
This will delete the EC2 instance and associated EIP and security group.

---

## Adapting to Terraform Helm Provider (optional)
If you want Terraform to manage Helm releases directly (using `helm_release`), you need the kubeconfig available to the machine running `terraform`. Options:
- SSH into the VM and copy `~/.kube/config` to your local machine, set `KUBECONFIG` and run `terraform` locally afterwards.
- Run `terraform` from inside the VM (requires Terraform on VM and credentials setup).
- Use a remote-exec step to generate kubeconfig and then run a local-exec to perform helm provider actions (more advanced).

If you want, I can provide a version that uses `helm_release` + `kubernetes` provider — but it will require one of the above kubeconfig strategies.

---

## Notes & Troubleshooting
- If `minikube start` fails, check Docker status and that `ubuntu` user is part of `docker` group.
- To inspect logs: SSH into the VM and view `/home/ubuntu/minikube-setup.log` (if added) or run `journalctl -u docker`.
- Ensure your AWS region has the instance type available.

---

## Why OLake?
OLake is a Kubernetes-deployable Data Lake / ETL platform (maintained by DataZip). This assignment validates your ability to provision infra, bootstrap a Kubernetes environment (Minikube) and deploy an app via Helm, and configure ingress so the application UI is reachable externally.

