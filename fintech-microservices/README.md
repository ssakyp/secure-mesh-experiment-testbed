# Design and Analysis of a Secure Microservice Platform Architecture

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Kubernetes](https://img.shields.io/badge/kubernetes-v1.30-blue?logo=kubernetes)](https://kubernetes.io/)
[![Istio](https://img.shields.io/badge/istio-v1.20-purple?logo=istio)](https://istio.io/)

This repository contains the official reproducibility artifact, empirical dataset scripts, and execution code for the research paper: **"Design and Analysis of a Secure Microservice Platform Architecture."** 

This project explores the performance-security trade-offs associated with zero-trust networking (specifically infrastructure-enforced mTLS via Envoy sidecars) versus application-layer token authorization (e.g., JWT) across a high-load, polyglot microservice cluster. 

Our statistical filtering and bootstrap methodology isolate cryptographic processing penalties from organic infrastructure and network exhaustion under various concurrent client loads (100 - 1000 Virtual Users).

## 🚀 Repository Structure

```text
.
├── k8s/                     # Kubernetes and Istio manifests (Baseline, JWT, mTLS, RBAC)
├── k6-tests/                # K6 synthetic load and scaling test scripts 
├── scripts/                 # Execution, load benchmarking, and cleanup routines
├── Makefile                 # Docker build sequences and image propagation
├── run_experiment.sh        # The primary, end-to-end operational execution script
├── obsv/                    # Observability setups (Prometheus/Grafana)
├── artifacts/               # Processed experiment output and filtered metric logs
└── {services}/              # 12 Polyglot Microservices (Go, Python, Java) 
```

## 🛠 Requirements & Prerequisites

The original experiment environment utilized an **Apple M1 Max (ARM64)**. However, the system is designed to compile and execute predictably on any x86_64/ARM64 standard environment with the following dependencies:

* **Docker / Colima:** Core containerization daemon (v0.6+ recommended if on MacOS)
* **K3d / K3s:** Lightweight, local, multi-node Kubernetes clustering tool (v5.6+)
* **kubectl:** The standard Kubernetes controller CLI 
* **Istio & istioctl:** Service mesh framework (v1.20+ recommended)
* **K6:** Grafana K6 load testing suite (v0.43+)

## ⚙️ How to Reproduce the Experiment

### Step 1: Environment Initialization
Start by bootstrapping an isolated Kubernetes cluster specifically shaped for this experiment:
```bash
# Provision a robust k3d cluster with routing extensions:
k3d cluster create research-cluster \
  --servers 1 \
  --agents 3 \
  --port "8080:80@loadbalancer" \
  --k3s-arg "--disable=traefik@server:0"

# Install Istio Base and CRDs
istioctl install --set profile=demo -y
kubectl label namespace default istio-injection=enabled
kubectl create namespace fintech-app
kubectl label namespace fintech-app istio-injection=enabled
```

### Step 2: System Boot and Workload Simulation
Execute the automated orchestrator to build local container images, push them to the cluster, validate pod deployments, and sequence traffic loads from Scenarios A (Baseline) through Scenario C (Strict mTLS). Wait for all components to synchronize.

```bash
chmod +x run_experiment.sh
./run_experiment.sh
```

### Step 3: Analysis
Once the script gracefully resolves and cleans the host memory daemon, all performance profiles, latency measurements, throughput thresholds, and application resource overhead (CPU/RAM bounds) will output automatically into the `./results` directory. Use these logs for further statistical modeling or comparative inference framework processing.

## ✍🏻 Authors & Citations
* **Sultan Sakyp** - *School of Information Technology and Engineering, Kazakh British Technical University* 

If you use these scripts or adapt this testbed to support academic benchmarks, please refer to the final Q1 publication standard archival DOI provided upon journal acceptance.

## 📄 License
This project is licensed under the MIT License - see the `LICENSE` file for details.
