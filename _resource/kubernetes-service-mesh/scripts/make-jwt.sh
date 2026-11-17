#!/usr/bin/env bash
# Create a signing key, its public JWKS, and two test JWTs for chapter 12.
#
#   ./scripts/make-jwt.sh
#
# Output in ./jwt (ignored by git):
#   key.pem          private key that signs the tokens (keep it secret in real life)
#   jwks.json        public key set; Istio's RequestAuthentication checks signatures with it
#   admin.jwt        token for "alice", role admin  (valid 1 year)
#   viewer.jwt       token for "bob",   role viewer (valid 1 year)
#   requestauthentication.yaml  Istio RequestAuthentication with jwks.json inline
#
# Needs only openssl and python3 (standard library).
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p jwt
cd jwt

ISSUER="https://auth.bookstore.local"
KID="bookstore-2026"

[[ -f key.pem ]] || openssl genrsa -out key.pem 2048 2>/dev/null

# Public key as a JWKS: modulus (n) and exponent (e), base64url without padding.
modulus_hex="$(openssl rsa -in key.pem -noout -modulus 2>/dev/null | cut -d= -f2)"
python3 - "$modulus_hex" "$KID" > jwks.json <<'PY'
import base64, json, sys
n = bytes.fromhex(sys.argv[1])
b64 = lambda b: base64.urlsafe_b64encode(b).rstrip(b"=").decode()
print(json.dumps({"keys": [{"kty": "RSA", "alg": "RS256", "use": "sig", "kid": sys.argv[2],
                             "n": b64(n), "e": b64((65537).to_bytes(3, "big"))}]}))
PY

# make_token <file> <subject> <role>
make_token() {
  local now exp header payload signature
  now="$(date +%s)"; exp=$((now + 365*24*3600))
  header="$(python3 -c 'import base64,json,sys; print(base64.urlsafe_b64encode(json.dumps({"alg":"RS256","typ":"JWT","kid":sys.argv[1]},separators=(",",":")).encode()).rstrip(b"=").decode())' "$KID")"
  payload="$(python3 -c 'import base64,json,sys; print(base64.urlsafe_b64encode(json.dumps({"iss":sys.argv[1],"sub":sys.argv[2],"role":sys.argv[3],"iat":int(sys.argv[4]),"exp":int(sys.argv[5])},separators=(",",":")).encode()).rstrip(b"=").decode())' "$ISSUER" "$2" "$3" "$now" "$exp")"
  signature="$(printf '%s.%s' "$header" "$payload" | openssl dgst -sha256 -sign key.pem -binary \
    | python3 -c 'import base64,sys; print(base64.urlsafe_b64encode(sys.stdin.buffer.read()).rstrip(b"=").decode())')"
  printf '%s.%s.%s\n' "$header" "$payload" "$signature" > "$1"
  echo "created $1 (sub=$2, role=$3)"
}

make_token admin.jwt alice admin
make_token viewer.jwt bob viewer

# RequestAuthentication for the ingress gateway, with this public key inline.
python3 - ../12-authorization/requestauthentication.yaml.tpl jwks.json > requestauthentication.yaml <<'PY'
import sys
template, jwks = open(sys.argv[1]).read(), open(sys.argv[2]).read().strip()
print(template.replace("JWKS_INLINE", jwks), end="")
PY
echo "created requestauthentication.yaml (issuer $ISSUER)"
