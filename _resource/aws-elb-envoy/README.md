# AWS ELB for Envoy: Run Your Envoy Config as a Managed Load Balancer

Example code for the article
[AWS ELB for Envoy: Run Your Own Envoy Configuration as a Managed Load Balancer](https://devopsvn.tech/aws-elb-for-envoy-managed-envoy-load-balancer/).

The `aws elb-proxy` commands need **AWS CLI 2.42.4 or later**. They were checked against the
CLI 2.42.4 command model and the [ELB for Envoy documentation](https://docs.aws.amazon.com/elasticloadbalancing/latest/elbproxy/what-is.html).
Both Envoy configs were validated and run locally on Envoy 1.40.2.
The scripts create billable resources (a proxy). Run `scripts/cleanup.sh` when you finish.

| Path | Purpose |
| --- | --- |
| `envoy/config.yaml` | Sample from the AWS getting-started guide: one listener on port 80, a fixed response. |
| `envoy/config-v2.yaml` | Adds a Lua API key check and a local rate limit (5 requests per 10 s per Envoy process). |
| `envoy/config-stdout-log.yaml` | "Break It": a `stdout` access logger. Passes local validation; ELB for Envoy rejects it. |
| `iam/*.json` | Trust policy and CloudWatch Logs permissions for the proxy role. |
| `scripts/env.sh` | Region (default `ap-southeast-1`), names, and IDs saved by earlier steps. Source it. |
| `scripts/run-local.sh` | Validate and run a config on your laptop with Docker (Envoy 1.40), on `localhost:18080`. |
| `scripts/01-iam.sh` | The proxy role. |
| `scripts/02-network.sh` | Two default subnets, a security group that allows port 80 from your IP, `network.json`. |
| `scripts/03-create-proxy.sh` | `create-proxy`, then poll until `active`. Saves the ARN and DNS name. |
| `scripts/04-update-config.sh` | `update-proxy-configuration` with `config-v2.yaml`, then poll the update. |
| `scripts/cleanup.sh` | Deletes the proxy, security group, role, and log group. |

## Run it

Requirements: AWS CLI 2.42.4+, credentials that can create IAM roles, security groups, and
proxies, Docker for the local step, and a default VPC in the Region.

```sh
scripts/run-local.sh envoy/config-v2.yaml     # optional: try it locally first (Ctrl+C to stop)

source scripts/env.sh
scripts/01-iam.sh
scripts/02-network.sh
scripts/03-create-proxy.sh                    # several minutes
source scripts/env.sh                         # load PROXY_ARN and DNS_NAME into this shell
curl "http://$DNS_NAME/"

scripts/04-update-config.sh
curl -i "http://$DNS_NAME/"                                  # 401: no API key
curl "http://$DNS_NAME/healthz"                              # ok
for i in $(seq 7); do curl -s -o /dev/null -w "%{http_code} " -H 'x-api-key: demo-key' "http://$DNS_NAME/"; done; echo

aws logs tail "/aws/elb-proxy/$NAME" --since 15m

scripts/cleanup.sh
```

The API key in `config-v2.yaml` is a demo value written in plain text in the config. Use the
`ext_authz` or `jwt_authn` filter for real authentication.
