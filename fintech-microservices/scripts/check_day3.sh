#!/bin/bash
cd /Users/sultansakyp/research/fintech-microservices/artifacts/runs
echo "Checking Day 3 runs..."
for d in 20260330-*; do
  if [ -d "$d" ] && [ -f "$d/k6_key_metrics.json" ]; then
      passes=$(jq -r '.metrics.checks.passes // 0' "$d/k6_key_metrics.json")
      fails=$(jq -r '.metrics.checks.fails // 0' "$d/k6_key_metrics.json")
      if [ "$passes" == "0" ] && [ "$fails" != "0" ]; then
         echo "FAILED RUN: $d"
      fi
  fi
done
echo "Day 3 Runs summary (Loads 700, 1000):"
for scen in A B C; do
  for load in 700 1000; do
    count=$(ls -d 20260330-*-${scen}-${load}-* 2>/dev/null | wc -l | tr -d ' ')
    echo "Scenario $scen, Load $load: $count runs"
  done
done
