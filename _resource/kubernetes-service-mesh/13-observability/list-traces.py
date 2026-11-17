"""List the most recent traces that include a service: trace ID, span count, services in it.

  python3 13-observability/list-traces.py storefront.bookstore
"""
import json
import sys
import urllib.request

service = sys.argv[1] if len(sys.argv) > 1 else "storefront.bookstore"
url = f"http://localhost:16686/jaeger/api/traces?service={service}&limit=4&lookback=5m"
rows = []
for trace in json.load(urllib.request.urlopen(url))["data"]:
    services = {k: v["serviceName"] for k, v in trace["processes"].items()}
    names = sorted({services[s["processID"]] for s in trace["spans"]})
    start = min(s["startTime"] for s in trace["spans"])
    rows.append((start, f'{trace["traceID"][:12]} {len(trace["spans"])} spans: {", ".join(names)}'))
for _, row in sorted(rows):
    print(row)
