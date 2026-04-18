#!/bin/bash
set -e
cd /Users/sultansakyp/research/fintech-microservices
mkdir -p results
echo "[1/7] Building and loading Polyglot Docker images..."
echo "This step will compile the Go, Python, and Java services. It may take 5-10 minutes."
make build push
echo "[2/7] Deploying Baseline Architecture & Observability Tools..."
kubectl apply -f k8s/baseline/deployment.yaml
kubectl apply -f k8s/baseline/gateway.yaml
# Enable stats tracking tools
kubectl apply -f https://raw.githubusercontent.com/istio/istio/master/samples/addons/prometheus.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/master/samples/addons/grafana.yaml
echo "Waiting for all pods to become ready..."
kubectl wait --for=condition=ready pod --all -n fintech-app --timeout=600s
sleep 15 # give system time to establish baseline metrics tracking
echo "[3/7] Running Load Test: Scenario A (Baseline)..."
k6 run k6-tests/fintech_load_test.js > results/scenario_A_baseline.txt
echo "[4/7] Deploying Scenario B (JWT Authentication)..."
kubectl apply -f k8s/jwt/jwt-auth.yaml
sleep 10 # wait for Envoy proxy config synchronization
echo "Fetching sample valid JWT..."
export JWT_TOKEN=$(curl -s https://raw.githubusercontent.com/istio/istio/release-1.20/security/tools/jwt/samples/demo.jwt)
echo "Running Load Test: Scenario B (JWT)..."
k6 run -e JWT_TOKEN=$JWT_TOKEN k6-tests/fintech_load_test.js > results/scenario_B_jwt.txt
echo "[5/7] Deploying Scenario C (Strict mTLS + Zero-Trust Authorization)..."
kubectl apply -f k8s/mtls/mtls-authz.yaml
sleep 10 # Wait for sidecars to flip to strict encryption
echo "Running Load Test: Scenario C (mTLS)..."
k6 run -e JWT_TOKEN=$JWT_TOKEN k6-tests/fintech_load_test.js > results/scenario_C_mtls.txt
echo "[6/7] Extracting Final Resource Overhead Metrics (CPU/RAM)..."
echo "--- POD CUMULATIVE RESOURCE METRICS (FINTECH-APP) ---" > results/resource_overhead.txt
kubectl top pods -n fintech-app --containers >> results/resource_overhead.txt || echo "Metrics server not responding fast enough" >> results/resource_overhead.txt
echo "--- SIDE-CAR ISTIO OVERHEAD VS APP PROCESS ---" >> results/resource_overhead.txt
kubectl top pods -n fintech-app >> results/resource_overhead.txt || true
echo "[7/7] Automation complete! Cleaning up local system resources..."
echo "Destroying k3d local cluster to preserve memory..."
k3d cluster delete research-cluster || true
echo "Shutting down the Colima Docker Daemon..."
colima stop || true
echo "==================================================================="
echo "Experiment Sequence Finished! The background apps have been closed."
echo "Your results are stored in: /Users/sultansakyp/research/fintech-microservices/results/"
echo "==================================================================="
