# AWS CDK Series — Code (Go)

Ready-to-use **AWS CDK v2 (Go)** code that accompanies the
[AWS CDK series](https://devopsvn.tech/aws-cdk-series/) on DevOps VN.

Each folder maps to a chapter. The `.go` files are the code you write — the rest of
a CDK project (`go.mod`, `cdk.json`, `*_test.go` scaffolding) is generated for you by
`cdk init`. To run any chapter:

```bash
# 1. Create a fresh CDK app
mkdir myapp && cd myapp
cdk init app --language go

# 2. Copy the chapter's .go files over the generated ones, then:
go mod tidy
cdk synth        # preview the CloudFormation
cdk deploy       # create the resources
cdk destroy      # tear them down
```

| Chapter | Folder | Topic |
|--------|--------|-------|
| 0 | `00-iac-and-cdk` | Hello CDK — a single EC2 |
| 1 | `01-init-app-and-config` | App init, config, an S3 bucket |
| 2 | `02-core-components` | App / Stack / Construct (EC2 + RDS) |
| 3 | `03-design-build-qa-infrastructure` | Multi-stack Q&A app (cache, worker, insert) |
| 4 | `04-construct-layers` | L1 / L2 / L3 constructs |
| 5 | `05-stacks` | Multiple stacks, sharing constructs, stages |
| 6 | `06-testing` | Unit & snapshot tests for CDK |
| 7 | `07-cicd` | CI/CD for CDK (GitHub Actions) |
| 8 | `08-best-practices` | Production best practices |
| 9 | `09-serverless-app` | Capstone: Lambda + API Gateway + DynamoDB |

> All code targets **CDK v2** with the latest APIs (Amazon Linux 2023,
> `SecretValue_UnsafePlainText`, pinned engine versions). Replace placeholder
> account IDs / passwords before deploying.

```bash
git clone https://github.com/VersusControl/devops-vn-blog.git
cd devops-vn-blog/_resource/aws-cdk-series
```
