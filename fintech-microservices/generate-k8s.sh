#!/bin/bash
mkdir -p k8s/baseline k8s/jwt k8s/mtls k6-tests
cat << 'YAML' > k8s/baseline/deployment.yaml
# FinTech Polyglot Microservices Kubernetes Manifests (Baseline)
# Applies to the 'fintech-app' namespace 
YAML
services=("api-gateway" "auth-service" "transaction-service" "audit-service" "currency-exchange" "user-profile" "notification-service" "fraud-analytics" "reporting-service" "account-service" "ledger-service" "card-management")
for svc in "${services[@]}"; do
  cat << YAML >> k8s/baseline/deployment.yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $svc
  namespace: fintech-app
  labels:
    app: $svc
spec:
  replicas: 1
  selector:
    matchLabels:
      app: $svc
  template:
    metadata:
      labels:
        app: $svc
    spec:
      containers:
      - name: $svc
        image: localhost:5000/fintech/$svc:latest
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 8080
        resources:
          requests:
            memory: "64Mi"
            cpu: "25m"
          limits:
            memory: "256Mi"
            cpu: "200m"
---
apiVersion: v1
kind: Service
metadata:
  name: $svc
  namespace: fintech-app
spec:
  selector:
    app: $svc
  ports:
    - protocol: TCP
      port: 8080
      targetPort: 8080
YAML
done
