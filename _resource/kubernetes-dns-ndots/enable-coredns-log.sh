#!/usr/bin/env bash
# Turn on the CoreDNS "log" plugin so every query is printed. For a test cluster only:
# on a busy cluster this logs every DNS query.
set -euo pipefail
kubectl -n kube-system get cm coredns -o json | python3 -c '
import json, sys
d = json.load(sys.stdin); c = d["data"]["Corefile"]
if "\n    log\n" not in c:
    c = c.replace("    errors\n", "    errors\n    log\n", 1)
d["data"]["Corefile"] = c
json.dump(d, sys.stdout)' | kubectl apply -f -
kubectl -n kube-system rollout restart deploy/coredns
kubectl -n kube-system rollout status deploy/coredns
