# Air-Gapped Kubernetes Cluster Automation (Ansible + Helm)

This repository contains my personal automation for building a **production-style, air-gapped Kubernetes cluster** using **Ansible** and **Helm**.

The goal of this project is to demonstrate:

- End-to-end provisioning of a multi-node Kubernetes cluster with **no direct Internet access** on control-plane and worker nodes.
- Use of a **bastion host** to provide an **offline container registry** and **RPM/YUM repositories**.
- Automated installation of **Calico CNI**, **ingress-nginx**, and a sample application via **Helm**.
- Infrastructure and configuration expressed as **idempotent Ansible roles** and **Helm charts/values**.

---

## 1. High-Level Architecture

At a high level, the environment looks like this (example using AWS EC2, but the pattern is generic):

- **Bastion Host**
  - Has Internet access (or temporary staged access).
  - Mirrors OS packages into **offline YUM repositories**.
  - Hosts a **private container registry** (e.g. registry on port 5000).
  - Acts as Ansible control node and jump host for SSH.
- **Kubernetes API Load Balancer**
  - Runs **HAProxy** (TCP mode) in front of all control-plane nodes.
  - Exposes `kube-apiserver` on a stable VIP (e.g. `k8s-lb:6443`).
- **Control-Plane Nodes** (e.g. 3 nodes)
  - Installed with `kubeadm` using the HAProxy endpoint as `controlPlaneEndpoint`.
  - Run `kube-apiserver`, `kube-scheduler`, `kube-controller-manager`, and stacked `etcd`.
- **Worker Nodes** (e.g. 3 nodes)
  - Join the cluster via `kubeadm join`.
  - Run workloads and **ingress-nginx**.
- **Application Ingress / Load Balancer (optional)**
  - An external HAProxy or L4/L7 load balancer in front of the ingress-nginx service (NodePort).
  - Used to expose HTTP/HTTPS applications from the cluster.

Conceptual diagram (simplified):

```mermaid
flowchart LR
    user[User / Browser] --> appLB[App Load Balancer]
    appLB --> ingress[Ingress Controller]
    ingress --> svc[ClusterIP Services]
    svc --> pods[Application Pods]

    subgraph Air-Gapped_VPC
        subgraph Bastion_Subnet
            bastion[Bastion Host - Ansible, Offline Registry, Offline YUM Repos]
        end

        subgraph Private_Subnets
            lb[HAProxy - API Load Balancer]

            subgraph ControlPlane_Nodes
                cp1[master-01]
                cp2[master-02]
                cp3[master-03]
            end

            subgraph Worker_Nodes
                w1[worker-01]
                w2[worker-02]
                w3[worker-03]
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
    end```

