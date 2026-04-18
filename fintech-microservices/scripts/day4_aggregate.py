#!/usr/bin/env python3
import csv
import json
import os
import re
from pathlib import Path
from statistics import mean
ROOT = Path("/Users/sultansakyp/research/fintech-microservices")
RUNS_DIR = ROOT / "artifacts" / "runs"
QUAR_DIR = ROOT / "artifacts" / "quarantined_runs"
PROCESSED_DIR = ROOT / "artifacts" / "processed"
MASTER_CSV = PROCESSED_DIR / "master_dataset.csv"
OUTLIER_CSV = PROCESSED_DIR / "outlier_log.csv"
REPORT_MD = ROOT / "DATA_QUALITY_REPORT.md"
RUN_RE = re.compile(r"^(?P<date>\d{8})-(?P<hhmm>\d{4})-(?P<scenario>[ABC])-(?P<load>\d+)-(?P<rep>\d{2})$")
def read_json(path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)
def collect_runs():
    rows = []
    outliers = []
    if not RUNS_DIR.exists():
        raise SystemExit(f"Runs directory not found: {RUNS_DIR}")
    for run_dir in sorted(RUNS_DIR.iterdir()):
        if not run_dir.is_dir():
            continue
        m = RUN_RE.match(run_dir.name)
        if not m:
            outliers.append({
                "run_id": run_dir.name,
                "reason": "invalid_run_id_format",
                "action": "excluded"
            })
            continue
        k6_path = run_dir / "k6_key_metrics.json"
        if not k6_path.exists():
            outliers.append({
                "run_id": run_dir.name,
                "reason": "missing_k6_key_metrics_json",
                "action": "excluded"
            })
            continue
        try:
            k6 = read_json(k6_path)
        except Exception as e:
            outliers.append({
                "run_id": run_dir.name,
                "reason": f"json_parse_error:{e}",
                "action": "excluded"
            })
            continue
        metrics = k6.get("metrics", {})
        checks = metrics.get("checks", {})
        dur = metrics.get("http_req_duration", {})
        reqs = metrics.get("http_reqs", {})
        passes = checks.get("passes", 0) or 0
        fails = checks.get("fails", 0) or 0
        checks_value = checks.get("value", 0.0) or 0.0
        if passes == 0 and fails > 0:
            outliers.append({
                "run_id": run_dir.name,
                "reason": "all_checks_failed_previously_unfiltered",
                "action": "excluded"
            })
            continue
        row = {
            "run_id": run_dir.name,
            "date": m.group("date"),
            "hhmm": m.group("hhmm"),
            "scenario": m.group("scenario"),
            "load": int(m.group("load")),
            "rep": int(m.group("rep")),
            "checks_passes": int(passes),
            "checks_fails": int(fails),
            "checks_value": float(checks_value),
            "http_avg_ms": float(dur.get("avg", 0.0) or 0.0),
            "http_min_ms": float(dur.get("min", 0.0) or 0.0),
            "http_med_ms": float(dur.get("med", 0.0) or 0.0),
            "http_p90_ms": float(dur.get("p(90)", 0.0) or 0.0),
            "http_p95_ms": float(dur.get("p(95)", 0.0) or 0.0),
            "http_max_ms": float(dur.get("max", 0.0) or 0.0),
            "http_count": int(reqs.get("count", 0) or 0),
            "http_rate_rps": float(reqs.get("rate", 0.0) or 0.0),
        }
        flags = []
        if row["checks_value"] < 0.95:
            flags.append("low_success_ratio")
        if row["http_p95_ms"] > 10000:
            flags.append("high_p95")
        if row["http_rate_rps"] < 50:
            flags.append("very_low_rps")
        row["quality_flags"] = ";".join(flags)
        rows.append(row)
    return rows, outliers
def write_csv(path, rows, fieldnames):
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        for r in rows:
            w.writerow(r)
def summarize(rows):
    by_cell = {}
    for r in rows:
        key = (r["scenario"], r["load"])
        by_cell.setdefault(key, []).append(r)
    lines = []
    lines.append("| Scenario | Load | Runs | Avg p95 (ms) | Avg RPS | Avg Success Ratio |")
    lines.append("|---|---:|---:|---:|---:|---:|")
    for (scenario, load) in sorted(by_cell.keys(), key=lambda x: (x[1], x[0])):
        cell = by_cell[(scenario, load)]
        avg_p95 = mean([x["http_p95_ms"] for x in cell]) if cell else 0.0
        avg_rps = mean([x["http_rate_rps"] for x in cell]) if cell else 0.0
        avg_ok = mean([x["checks_value"] for x in cell]) if cell else 0.0
        lines.append(f"| {scenario} | {load} | {len(cell)} | {avg_p95:.2f} | {avg_rps:.2f} | {avg_ok:.4f} |")
    return "\n".join(lines), by_cell
def main():
    PROCESSED_DIR.mkdir(parents=True, exist_ok=True)
    rows, outliers = collect_runs()
    master_fields = [
        "run_id","date","hhmm","scenario","load","rep",
        "checks_passes","checks_fails","checks_value",
        "http_avg_ms","http_min_ms","http_med_ms","http_p90_ms","http_p95_ms","http_max_ms",
        "http_count","http_rate_rps","quality_flags"
    ]
    outlier_fields = ["run_id","reason","action"]
    write_csv(MASTER_CSV, rows, master_fields)
    write_csv(OUTLIER_CSV, outliers, outlier_fields)
    summary_table, by_cell = summarize(rows)
    total_runs = len(rows)
    total_outliers = len(outliers)
    required = {
        ("A",100),("B",100),("C",100),
        ("A",300),("B",300),("C",300),
        ("A",500),("B",500),("C",500),
        ("A",700),("B",700),("C",700),
        ("A",1000),("B",1000),("C",1000),
    }
    missing_cells = sorted([c for c in required if c not in by_cell])
    underfilled = sorted([(k, len(v)) for k,v in by_cell.items() if len(v) < 5], key=lambda x: (x[0][1], x[0][0]))
    with open(REPORT_MD, "w", encoding="utf-8") as f:
        f.write("# DATA_QUALITY_REPORT.md\n\n")
        f.write("## Day 4 Data Integrity and Processing Report\n\n")
        f.write(f"- Valid runs in `master_dataset.csv`: **{total_runs}**\n")
        f.write(f"- Excluded/outlier runs in `outlier_log.csv`: **{total_outliers}**\n")
        f.write(f"- Source folder: `{RUNS_DIR}`\n")
        f.write(f"- Quarantine folder (pre-fix failed runs): `{QUAR_DIR}`\n\n")
        f.write("### Coverage Summary\n\n")
        f.write(summary_table + "\n\n")
        if missing_cells:
            f.write("### Missing Scenario-Load Cells (Action Required)\n\n")
            for s,l in missing_cells:
                f.write(f"- Missing: scenario `{s}`, load `{l}`\n")
            f.write("\n")
        else:
            f.write("### Missing Scenario-Load Cells\n\n- None\n\n")
        if underfilled:
            f.write("### Underfilled Cells (<5 runs)\n\n")
            for (s,l),cnt in underfilled:
                f.write(f"- scenario `{s}`, load `{l}`: {cnt} runs\n")
            f.write("\n")
        else:
            f.write("### Underfilled Cells (<5 runs)\n\n- None\n\n")
        f.write("### Day 4 Decision\n\n")
        if not missing_cells and not underfilled:
            f.write("- Dataset is sufficiently complete for Day 5 statistical analysis and figure generation.\n")
        else:
            f.write("- Additional reruns are required before final statistical locking.\n")
    print(f"Generated: {MASTER_CSV}")
    print(f"Generated: {OUTLIER_CSV}")
    print(f"Generated: {REPORT_MD}")
if __name__ == "__main__":
    main()
