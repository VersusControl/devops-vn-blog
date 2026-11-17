#!/usr/bin/env bash
# Run one PromQL query against Prometheus on localhost:9090 and print each series' labels
# and value, one per line. Start the port-forward first:
#   kubectl -n istio-system port-forward svc/prometheus 9090:9090
#
#   ./13-observability/promql.sh 'sum(rate(istio_requests_total[5m]))'
set -euo pipefail
curl -s http://localhost:9090/api/v1/query --data-urlencode "query=$1" | python3 -c '
import json, sys
for r in json.load(sys.stdin)["data"]["result"]:
    labels = " ".join(f"{k}={v}" for k, v in sorted(r["metric"].items()))
    print(labels or "{}", round(float(r["value"][1]), 3))'
