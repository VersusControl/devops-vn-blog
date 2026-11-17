"""Print the largest trace of the last 10 minutes for a service, as an indented tree.

Start the port-forward first:
  kubectl -n istio-system port-forward svc/tracing 16686:80

  python3 13-observability/show-trace.py istio-ingressgateway.istio-system
"""
import json
import sys
import urllib.request

service = sys.argv[1] if len(sys.argv) > 1 else "istio-ingressgateway.istio-system"
url = f"http://localhost:16686/jaeger/api/traces?service={service}&limit=20&lookback=10m"
traces = json.load(urllib.request.urlopen(url))["data"]
if not traces:
    sys.exit(f"no traces for {service} in the last 10 minutes")
trace = max(traces, key=lambda t: len(t["spans"]))
services = {k: v["serviceName"] for k, v in trace["processes"].items()}

children = {}
for span in trace["spans"]:
    parent = next((r["spanID"] for r in span.get("references", []) if r["refType"] == "CHILD_OF"), None)
    children.setdefault(parent, []).append(span)

def show(parent_id, depth):
    for span in sorted(children.get(parent_id, []), key=lambda s: s["startTime"]):
        tags = {t["key"]: t["value"] for t in span["tags"]}
        print(f'{"  " * depth}{services[span["processID"]]:<36} {span["operationName"]:<60} '
              f'{span["duration"] / 1000:7.1f} ms  {tags.get("http.status_code", "")}')
        show(span["spanID"], depth + 1)

print("trace", trace["traceID"], "spans", len(trace["spans"]))
show(None, 0)
