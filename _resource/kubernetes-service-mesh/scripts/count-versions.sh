#!/usr/bin/env bash
# Send N requests to the Book Store reviews API and count the answers by:
#   status code, reviews version, ratings result, and response time.
#
#   ./scripts/count-versions.sh [base-url] [requests]
#
#   ./scripts/count-versions.sh http://localhost:9000 30     # chapter 1 (port-forward)
#   ./scripts/count-versions.sh http://bookstore.local:8080 50   # through the gateway
#
# Host names ending in .local are sent to 127.0.0.1 (the Kind port mapping), the same
# as curl --resolve in the chapters, so you don't need an /etc/hosts entry.
#
# Columns in the output:
#   count  status  reviews-version  ratings  time
#   ratings: stars | no-stars (v1 doesn't call ratings) | ratings-error | - (reviews didn't answer)
#   time:    fast (<1 s) | 1-3s | 3-8s | slow (>8 s)
#
# Environment variables:
#   HOST_HEADER  send a different Host header
#   CURL_OPTS    extra curl options, split on spaces, for example a cookie file:
#                CURL_OPTS='-b /tmp/qa-cookies.txt' ./scripts/count-versions.sh   (a saved login)
set -uo pipefail
base="${1:-http://localhost:8080}"
n="${2:-20}"
host_args=()
[[ -n "${HOST_HEADER:-}" ]] && host_args=(-H "Host: $HOST_HEADER")

# http(s)://name.local:port/... -> --resolve name.local:port:127.0.0.1
if [[ "$base" =~ ^(https?)://([^/:]+\.local)(:([0-9]+))? ]]; then
  port="${BASH_REMATCH[4]}"
  [[ -z "$port" ]] && { [[ "${BASH_REMATCH[1]}" == https ]] && port=443 || port=80; }
  host_args+=(--resolve "${BASH_REMATCH[2]}:$port:127.0.0.1")
fi

for _ in $(seq "$n"); do
  # shellcheck disable=SC2086
  out="$(curl -s -m 30 ${CURL_OPTS:-} ${host_args[@]+"${host_args[@]}"} \
          -w '\n%{http_code} %{time_total}' "$base/api/v1/products/0/reviews")"
  meta="${out##*$'\n'}"
  body="${out%$'\n'*}"
  code="${meta%% *}"
  secs="${meta##* }"

  version="$(printf '%s' "$body" | grep -o '"podname": *"reviews-v[0-9]*' | grep -o 'v[0-9]*$')"
  if   [[ -z "$version" ]];                        then ratings="-"   # reviews didn't answer
  elif printf '%s' "$body" | grep -q '"error"'; then ratings="ratings-error"
  elif printf '%s' "$body" | grep -q '"stars"'; then ratings="stars"
  else ratings="no-stars"
  fi

  time_bucket="$(awk -v t="$secs" 'BEGIN {
    if (t < 1) print "fast"; else if (t < 3) print "1-3s"; else if (t < 8) print "3-8s"; else print "slow" }')"

  printf '%s %s %s %s\n' "$code" "reviews-${version:-none}" "$ratings" "$time_bucket"
done | sort | uniq -c | sort -rn
