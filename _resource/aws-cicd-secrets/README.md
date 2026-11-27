# Keep secrets out of AWS CI/CD pipelines

Example code for the article
[AWS CI/CD Security Mistakes to Avoid](https://devopsvn.tech/aws-cicd-security-mistakes/).

| File | Purpose |
| --- | --- |
| `buildspec-insecure.yaml` | What not to do: keys, a password, an SSH key and a server IP in the file. All values are fake. |
| `buildspec-secure.yaml` | The same build with an IAM role, `parameter-store` / `secrets-manager`, and SSM instead of SSH. |
| `github/trust-policy.json` | IAM role trust policy for GitHub Actions OIDC, limited to one repo and branch. |
| `github/deploy.yml` | A GitHub Actions workflow that assumes that role. No AWS keys in GitHub. |
| `scan.sh` | Runs gitleaks against a repository's history. |

The buildspecs, trust policy and workflow follow the AWS CodeBuild and GitHub documentation; they
were not run in an AWS account. `scan.sh` was run with gitleaks 8.30.1.
