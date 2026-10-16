# TravelMemory — AWS Deployment with Terraform and Ansible

## Project Overview

This project deploys the TravelMemory MERN application on AWS. Terraform provisions the infrastructure, and Ansible configures MongoDB, deploys the application, and configures Nginx.

## Architecture

The deployment consists of:

- An internet-facing AWS Application Load Balancer (ALB).
- Two application EC2 instances in separate Availability Zones.
- Nginx serving the React frontend and reverse-proxying API requests to Node.js.
- A private MongoDB EC2 instance with authentication enabled.
- AWS Systems Manager (SSM) for administration and Ansible connectivity.
- Terraform for infrastructure provisioning.
- Ansible for repeatable application and database configuration.

![TravelMemory AWS Architecture](docs/15.TravelMemoryArchitecture.png)

## Technology Stack

| Component | Technology |
|---|---|
| Infrastructure as Code | Terraform |
| Configuration management | Ansible |
| Cloud platform | AWS |
| Application frontend | React |
| Application backend | Node.js, Express |
| Database | MongoDB |
| Web server and reverse proxy | Nginx |
| Administration | AWS Systems Manager |
| Load balancing | AWS Application Load Balancer |

## Repository Structure

```text
.
├── ansible/
│   ├── group_vars/
│   ├── inventory/
│   ├── playbooks/
│   └── templates/
├── docs/
│   ├── architecture.drawio
│   ├── deployment-notes.md
│   └── evidence/
├── terraform/
│   ├── main.tf
│   ├── outputs.tf
│   ├── variables.tf
│   └── .terraform.lock.hcl
├── .gitignore
└── README.md
```

Terraform state files, variable files containing local configuration, provider working directories, and backup files must not be committed.

## Prerequisites

- AWS CLI configured with suitable permissions.
- Terraform installed.
- Python and Ansible installed in a virtual environment.
- The `amazon.aws` Ansible collection.
- AWS Systems Manager connectivity and appropriate IAM permissions.
- An Ansible Vault password for the encrypted database variables.
- A local checkout of the TravelMemory application source.

## Deployment Workflow

### 1. Provision AWS infrastructure

From the `terraform` directory, initialize Terraform and review the proposed changes before applying them:

```bash
terraform init
terraform validate
terraform plan
```

Review the plan carefully before running `terraform apply`. Never commit Terraform state files or secret variable files.

### 2. Configure Ansible

The inventory is located at:

`ansible/inventory/ssm.ini`

The inventory connects to EC2 instances through AWS Systems Manager. Database credentials are stored in the encrypted Ansible Vault variables file:

`ansible/group_vars/travelmemory_db/vars.yml`

Supply the Vault password interactively when prompted. Do not store the Vault password in the repository.

### 3. Deploy MongoDB

The database playbook is:

`ansible/playbooks/database.yml`

It configures MongoDB, enables authentication, and provisions the application database user.

### 4. Deploy the application

Build the frontend from the TravelMemory source checkout, then deploy the application with:

```bash
export ANSIBLE_COLLECTIONS_PATH="$HOME/.ansible/collections:/usr/lib/python3/dist-packages/ansible_collections:/usr/share/ansible/collections"

~/venvs/travelmemory-ansible/bin/ansible-playbook \
  -i ansible/inventory/ssm.ini \
  ansible/playbooks/application.yml \
  --ask-vault-pass
```

The application playbook installs Node.js and Nginx, deploys the backend and frontend, configures the backend environment, and enables the relevant system services.

## Verification

The deployment was verified with the following checks:

- Both application instances reported healthy in the ALB target group.
- The backend `/hello` endpoint returned HTTP 200.
- The frontend `/` endpoint returned HTTP 200.
- The trip API `/trip` returned HTTP 200 with an empty JSON array.
- A direct MongoDB connection and administrative ping from App A succeeded.
- Both application backend systemd services were active.
- MongoDB authentication was configured and verified.

An empty response from `/trip` indicates that no trip records were returned. It does not mean the application contains seeded sample data.

## Evidence

Screenshots documenting infrastructure provisioning, SSM connectivity, MongoDB configuration, application deployment, ALB health, and frontend access are stored in `docs/evidence/`.

## Security Notes

- Keep `terraform.tfstate`, `terraform.tfvars`, plaintext environment files, private keys, and Vault passwords out of version control.
- Commit the encrypted Ansible Vault file only; never commit decrypted credentials.
- Restrict security-group access to the required sources and ports.
- Use SSM for administration where possible instead of exposing SSH broadly.
- Review IAM permissions before deployment.
- The current application endpoint uses HTTP. Configure HTTPS before treating this deployment as production-ready.

## DNS

Custom-domain DNS configuration is a separate step. Do not consider Cloudflare configured until the required DNS records have been created and verified.

## Cost and Cleanup

AWS resources such as EC2 instances, NAT Gateways, and load balancers can incur charges while running.

When the demonstration is complete, review the Terraform destroy plan and all manually created resources before cleanup. Do not destroy resources until you have saved the required evidence and confirmed that the environment is no longer needed.

## Submission

The repository should include the Terraform configuration, Ansible playbooks and templates, architecture diagram, deployment notes, and evidence screenshots. Submit the final GitHub repository URL through the required Vlearn submission process.
