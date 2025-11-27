k8s-airgap-installer

A fully automated, air-gapped, multi-master Kubernetes cluster deployment using Ansible and Helm. Includes offline container registry, offline YUM repositories, HA control plane with HAProxy, Calico CNI, ingress-nginx, and production-grade cluster bootstrapping.

Air-Gapped Kubernetes Cluster Automation (Ansible + Helm)

This repository contains my personal automation for building a production-style, air-gapped Kubernetes cluster using Ansible and Helm.

The goal of this project is to demonstrate:

End-to-end provisioning of a multi-node Kubernetes cluster with no direct Internet access on control-plane and worker nodes.

Use of a bastion host to provide an offline container registry and RPM/YUM repositories.

Automated installation of Calico CNI, ingress-nginx, and a sample application via Helm.

Infrastructure and configuration expressed as idempotent Ansible roles and Helm charts/values.

1. High-Level Architecture

At a high level, the environment looks like this (example using AWS EC2, but the pattern is generic):

Bastion Host

Has Internet access (or temporary staged access)

Hosts offline YUM repos and private image registry

Runs Ansible

Kubernetes API Load Balancer

HAProxy (TCP) in front of control-plane nodes

Control-Plane Nodes

kubeadm-based HA cluster behind HAProxy

Worker Nodes

Run workloads + ingress-nginx

Optional Application Load Balancer

HAProxy or L4/L7 LB in front of ingress controller NodePort

Conceptual diagram:

flowchart LR
    user["User / Browser"] --> appLB["App Load Balancer"]
    appLB --> ingress["ingress-nginx on workers"]
    ingress --> svc["ClusterIP Services"]
    svc --> pods["Application Pods"]

    subgraph "Air-Gapped VPC"
        subgraph "Bastion Subnet"
            bastion["Bastion Host<br/>+ Ansible<br/>+ Offline Registry<br/>+ RPM Repos"]
        end

        subgraph "Private Subnets"
            lb["HAProxy<br/>API Load Balancer"]

            subgraph "Control-Plane Nodes"
                cp1["master-01"]
                cp2["master-02"]
                cp3["master-03"]
            end

            subgraph "Worker Nodes"
                w1["worker-01"]
                w2["worker-02"]
                w3["worker-03"]
            end
        end

        bastion --> lb
        lb --> cp1
        lb --> cp2
        lb --> cp3
        bastion --> cp1
        bastion --> cp2
        bastion --> cp3
        bastion --> w1
        bastion --> w2
        bastion --> w3
    end


All control-plane and worker nodes are in private subnets with no direct Internet access.
They reach:

offline YUM repos (bastion)

offline container registry (bastion)

Kubernetes API via HAProxy

2. Key Features
Air-gapped friendly

No Internet required on nodes

Pre-mirrored RPMs + container images

Ansible-driven automation

Node prerequisites

Container runtime setup

kubeadm init

Control-plane + worker join

Offline registry + repo setup

Calico CNI

Helm + ingress-nginx

HA control plane

Multi-master

Single HAProxy endpoint

CNI: Calico

Offline manifest + image hosting

Ingress-nginx

Offline Helm chart

Custom values

Host-based routing

Sample application

Test app to validate networking + ingress

3. Repository Structure
.
├── ansible/
│   ├── inventories/
│   │   └── hosts.yaml
│   ├── group_vars/
│   │   └── all.yaml
│   ├── roles/
│   │   ├── bastion_offline_registry/
│   │   ├── node_prereqs/
│   │   ├── containerd_install/
│   │   ├── kube_binaries/
│   │   ├── kubeadm_init/
│   │   ├── kubeadm_join_controlplane/
│   │   ├── kubeadm_join_worker/
│   │   ├── calico_install/
│   │   ├── helm_install/
│   │   └── ingress_deploy/
│   └── site.yaml
├── helm/
│   ├── charts/
│   │   └── ingress-nginx-4.11.0.tgz
│   └── values/
│       └── ingress-nginx-values.yaml
├── docs/
│   └── architecture.md
└── README.md

4. Air-Gap Strategy
4.1. Mirror packages & images

Mirror YUM repos

Download Kubernetes, Calico, ingress-nginx images

Save images as tar

Transfer to bastion

4.2. Bastion Host Setup

Private Docker/registry

Serve offline repos

Load & re-tag images

HAProxy for Kubernetes API

SELinux settings

5. Ansible Workflow
1) Prepare inventory & variables
ansible/inventories/hosts.yaml
ansible/group_vars/all.yaml

2) Bootstrap bastion
ansible-playbook -i inventories/hosts.yaml site.yaml --tags "bastion"

3) Prepare nodes
ansible-playbook -i inventories/hosts.yaml site.yaml --tags "node_prereqs,containerd_install"

4) Initialize first master
ansible-playbook -i inventories/hosts.yaml site.yaml --tags "kubeadm_init"

5) Join control-plane + workers
ansible-playbook -i inventories/hosts.yaml site.yaml --tags "kubeadm_join_controlplane,kubeadm_join_worker"

6) Install Calico
ansible-playbook -i inventories/hosts.yaml site.yaml --tags "calico_install"

7) Install Helm + ingress
ansible-playbook -i inventories/hosts.yaml site.yaml --tags "helm_install,ingress_deploy"

8) Deploy sample app

Verify ingress, DNS, networking.
