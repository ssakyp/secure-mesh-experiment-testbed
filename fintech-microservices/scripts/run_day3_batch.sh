#!/usr/bin/env bash
set -euo pipefail
ROOT="/Users/sultansakyp/research/fintech-microservices"
ARTIFACTS="$ROOT/artifacts/runs"
K6_SCRIPT="$ROOT/k6-tests/fintech_load_test.js"
NS="fintech-app"
LOADS=(700 1000)
SCENARIOS=(A B C)
REPS="${1:-10}"   
DATE_TAG="$(date +%Y%m%d)"
TIMEZONE_NOTE="$(date +%Z)"
need_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "Missing required command: $1"; exit 1; }; }
timestamp_hhmm() { date +%H%M; }
run_id() { printf "%s-%s-%s-%s-%02d" "$DATE_TAG" "$(timestamp_hhmm)" "$1" "$2" "$3"; }
apply_scenario() {
  local scen="$1"
  kubectl delete -f "$ROOT/k8s/jwt/jwt-auth.yaml" --ignore-not-found=true >/dev/null 2>&1 || true
  kubectl delete -f "$ROOT/k8s/mtls/mtls-authz.yaml" --ignore-not-found=true >/dev/null 2>&1 || true
  sleep 4
  case "$scen" in
    A) echo "[scenario:A] Baseline";;
    B) echo "[scenario:B] JWT-only"; kubectl apply -f "$ROOT/k8s/jwt/jwt-auth.yaml" >/dev/null;;
    C) echo "[scenario:C] Strict mTLS+AuthZ"; kubectl apply -f "$ROOT/k8s/mtls/mtls-authz.yaml" >/dev/null;;
    *) echo "Unknown scenario: $scen"; exit 1;;
  esac
  sleep 6
}
run_k6_once() {
  local scen="$1" load="$2" outdir="$3"
  local token=""
  if [[ "$scen" == "B" || "$scen" == "C" ]]; then
    token="$(curl -s https://raw.githubusercontent.com/istio/istio/release-1.20/security/tools/jwt/samples/demo.jwt || true)"
  fi
  if [[ -n "$token" ]]; then
    JWT_TOKEN="$token" k6 run \
      --vus "$load" --duration 60s \
      --summary-export "$outdir/k6_summary.json" "$K6_SCRIPT" > "$outdir/k6_stdout.txt" 2>&1
  else
    k6 run \
      --vus "$load" --duration 60s \
      --summary-export "$outdir/k6_summary.json" "$K6_SCRIPT" > "$outdir/k6_stdout.txt" 2>&1
  fi
}
collect_cluster_metrics() {
  local outdir="$1"
  kubectl top pods -n "$NS" --containers > "$outdir/kubectl_top_containers.txt" 2>&1 || true
  kubectl top pods -n "$NS" > "$outdir/kubectl_top_pods.txt" 2>&1 || true
  kubectl get pods -n "$NS" -o wide > "$outdir/pods_snapshot.txt" 2>&1 || true
}
write_run_meta() {
  local outdir="$1" scen="$2" load="$3" rep="$4"
  cat > "$outdir/run_meta.md" <<META
# Run Metadata
- Scenario: ${scen}
- Load tier: ${load}
- Repetition: ${rep}
- Timezone: ${TIMEZONE_NOTE}
- Timestamp: $(date -Iseconds)
- Namespace: ${NS}
META
}
need_cmd kubectl
need_cmd k6
if command -v jq >/dev/null 2>&1; then HAS_JQ=1; else HAS_JQ=0; fi
mkdir -p "$ARTIFACTS"
kubectl cluster-info >/dev/null || { echo "Cluster not ready"; exit 1; }
kubectl get ns "$NS" >/dev/null || { echo "Namespace not found"; exit 1; }
echo "[batch] Day 3 start: reps=$REPS"
for rep in $(seq 1 "$REPS"); do
  for scen in "${SCENARIOS[@]}"; do
    apply_scenario "$scen"
    for load in "${LOADS[@]}"; do
      RID="$(run_id "$scen" "$load" "$rep")"
      OUTDIR="$ARTIFACTS/$RID"
      mkdir -p "$OUTDIR"
      echo "[run] $RID"
      write_run_meta "$OUTDIR" "$scen" "$load" "$rep"
      run_k6_once "$scen" "$load" "$OUTDIR"
      collect_cluster_metrics "$OUTDIR"
      if [[ "$HAS_JQ" == "1" ]]; then
          jq '{metrics: .metrics | {http_req_duration, http_reqs, checks}}' "$OUTDIR/k6_summary.json" > "$OUTDIR/k6_key_metrics.json" 2>/dev/null || true
      fi
    done
  done
done
echo "[done] Day 3 batch complete. Artifacts: $ARTIFACTS"
