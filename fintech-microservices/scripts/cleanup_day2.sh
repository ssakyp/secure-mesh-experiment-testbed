#!/bin/bash
cd /Users/sultansakyp/research/fintech-microservices/artifacts
mkdir -p quarantined_runs
cd runs
echo "Checking Day 2 runs..."
for d in 20260329-*; do
  if [ -d "$d" ] && [ -f "$d/k6_key_metrics.json" ]; then
      passes=$(jq -r '.metrics.checks.passes // 0' "$d/k6_key_metrics.json")
      fails=$(jq -r '.metrics.checks.fails // 0' "$d/k6_key_metrics.json")
      if [ "$passes" == "0" ] && [ "$fails" != "0" ]; then
         echo "Quarantining bad pre-fix run: $d"
         mv "$d" ../quarantined_runs/
      fi
  fi
done
echo "Remaining VALID Day 2 runs (Target >= 5 per cell):"
for scen in A B C; do
  for load in 100 300 500; do
    count=$(ls -d 20260329-*-${scen}-${load}-* 2>/dev/null | wc -l | tr -d ' ')
    echo "Scenario $scen, Load $load: $count runs"
  done
done
