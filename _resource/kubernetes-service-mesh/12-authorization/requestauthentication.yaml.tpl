# Validate JWTs at the ingress gateway. scripts/make-jwt.sh fills in JWKS_INLINE with
# the public key it generated and writes the result to jwt/requestauthentication.yaml.
# A request with a valid token gets a "request principal" (<issuer>/<subject>) and its
# claims; a request with an invalid token is rejected with 401; a request with no token
# passes through with no principal (an AuthorizationPolicy decides what to do with it).
apiVersion: security.istio.io/v1
kind: RequestAuthentication
metadata:
  name: bookstore-jwt
  namespace: istio-system
spec:
  selector:
    matchLabels:
      istio: ingressgateway
  jwtRules:
    - issuer: "https://auth.bookstore.local"
      jwks: |
        JWKS_INLINE
