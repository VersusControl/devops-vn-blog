#!/usr/bin/env bash
# Create a local certificate authority (CA) and the certificates for chapter 4.
#
#   ./scripts/make-certs.sh
#
# Output in ./certs (ignored by git):
#   ca.crt / ca.key                      the "Book Store Local CA"; curl trusts it with --cacert
#   bookstore.local.crt / .key           server certificate for https://bookstore.local:8443
#   api.bookstore.local.crt / .key       server certificate for the partner API (MUTUAL TLS)
#   payments.bookstore.local.crt / .key  server certificate held by the payments app (PASSTHROUGH)
#   partner-client.crt / .key            client certificate a partner presents to api.bookstore.local
#
# For learning only: the CA key sits next to the certificates, unencrypted.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p certs
cd certs

if [[ ! -f ca.crt ]]; then
  openssl req -x509 -newkey rsa:2048 -nodes -sha256 -days 365 \
    -subj "/O=Book Store/CN=Book Store Local CA" \
    -keyout ca.key -out ca.crt 2>/dev/null
  echo "created ca.crt"
fi

# issue <name> <extendedKeyUsage>
issue() {
  local name="$1" usage="$2"
  [[ -f "$name.crt" ]] && return
  openssl req -newkey rsa:2048 -nodes -sha256 \
    -subj "/O=Book Store/CN=$name" -keyout "$name.key" -out "$name.csr" 2>/dev/null
  {
    echo "basicConstraints=CA:FALSE"
    echo "extendedKeyUsage=$usage"
    [[ "$usage" == serverAuth ]] && echo "subjectAltName=DNS:$name"
  } > "$name.ext"
  openssl x509 -req -sha256 -days 365 -in "$name.csr" -CA ca.crt -CAkey ca.key \
    -CAcreateserial -extfile "$name.ext" -out "$name.crt" 2>/dev/null
  rm -f "$name.csr" "$name.ext"
  echo "created $name.crt"
}

issue bookstore.local serverAuth
issue api.bookstore.local serverAuth
issue payments.bookstore.local serverAuth
issue partner-client clientAuth
