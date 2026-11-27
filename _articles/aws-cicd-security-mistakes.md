---
layout: post
title: "AWS CI/CD Security Mistakes to Avoid"
subtitle: "Four kinds of secrets that end up in pipeline files, how they leak, and the AWS features that let a pipeline deploy with no stored keys, passwords, or SSH."
date: 2026-11-28
author: Quan Huynh
tags: [aws, ci-cd, security, codebuild, github-actions, iam]
image: /assets/images/posts/aws-cicd-security-mistakes/cover.svg
---

A CI/CD pipeline needs access to things: a bucket to upload to, a database to migrate, a server to
deploy to. The fastest way to give it that access is to paste the credentials into the pipeline
file. It works on the first try, so it stays. Months later the repository is shared with a
contractor, or a fork is made public, and those credentials go with it.

Whoever holds a leaked AWS access key can do anything its permissions allow: start expensive
instances to mine cryptocurrency, copy your data, or delete it. The bill and the cleanup land on
you.

By the end of this post you will be able to:

- spot the four kinds of secrets that end up in pipeline files;
- give AWS CodeBuild and GitHub Actions access to AWS with no stored keys;
- pull database passwords from Parameter Store or Secrets Manager at build time;
- deploy to EC2 without SSH keys or open ports;
- catch secrets that slip in with a scanner, and know what to do if one leaks.

> **Code for this post:** [_resource/aws-cicd-secrets](https://github.com/VersusControl/devops-vn-blog/tree/main/_resource/aws-cicd-secrets).
> The buildspecs, IAM trust policy, and GitHub Actions workflow follow the AWS CodeBuild and GitHub
> documentation. I didn't run them in an AWS account. The secret scan ran for real with gitleaks
> 8.30.1, and its output is below.

## A Pipeline File That Works (and Leaks)

This is an AWS CodeBuild `buildspec.yaml`, the file that tells CodeBuild what to run. Every value
here is fake:

```yaml
# DON'T DO THIS. Every secret here is fake, kept to show what a leak looks like.
version: 0.2
env:
  variables:
    AWS_ACCESS_KEY_ID: AKIA-NOT-A-REAL-KEY-ID
    AWS_SECRET_ACCESS_KEY: 7Ws9xPq1Vn2bLk8Rt4Yz6Hj3Mc5Fg0Ds2Ae7Kp9Q
    DB_USER: admin
    DB_PASSWORD: Sup3rS3cret!
phases:
  build:
    commands:
      - aws s3 cp ./dist s3://my-app-site/ --recursive
      - scp -i deploy.pem db.env ec2-user@54.12.34.56:/opt/app/
```

The build works, and it gives away four things an attacker wants:

- An AWS access key, which works from anywhere until someone deactivates or deletes it.
- A database password in plain text.
- An SSH key (`deploy.pem`) that has to live next to the pipeline for `scp` to work.
- A server's public IP. It tells an attacker where to point that key, and it means port 22 is open
  to wherever the build runs.

Everyone who can read the repository can read these values. Anyone who can read the build logs may
see them too, because a debug line or a failing command can print them. And Git keeps every old version of the
file, so deleting the line later doesn't remove the secret from history.

The rest of this post removes them one at a time: the access key, then the password, then the SSH
key and IP.

![Before and after: the insecure pipeline file holds an AWS access key, a DB password, an SSH key, and a server IP, and reaches AWS APIs and an EC2 instance with port 22 open over the public internet; the secure pipeline holds no secrets, assumes an IAM role or uses OIDC for temporary credentials, reads the password from Parameter Store at build time, and deploys through Systems Manager Run Command to an EC2 instance with port 22 closed](/assets/images/posts/aws-cicd-security-mistakes/before-after-pipeline.svg)

## Fix 1: No AWS Keys, Use a Role

An *IAM role* is an identity that a service can take on for a short time. AWS gives the service
*temporary credentials* that expire on their own, so there's no long-lived key to store or leak.

### CodeBuild

A CodeBuild project runs with a *service role*. Give that role only the permissions the build needs
(for example, `s3:PutObject` on one bucket), and delete the keys from the file. The AWS CLI inside
the build picks up the role's credentials automatically, so the command stays the same:

```yaml
phases:
  build:
    commands:
      - aws s3 cp ./dist s3://my-app-site/ --recursive   # no keys anywhere
```

### GitHub Actions

A pipeline that runs outside AWS can also avoid stored keys by using *OIDC* (OpenID Connect).
GitHub gives each workflow run a signed token that says which repository and branch the run comes
from. AWS checks that token and returns temporary credentials for a role you choose.

You set this up once in IAM. First, add `token.actions.githubusercontent.com` as an identity
provider. Then create a role that trusts that provider, but only for your repository and branch.
This is the condition block of the role's trust policy (the full policy is in
`github/trust-policy.json`):

```json
"Condition": {
  "StringEquals": {
    "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
    "token.actions.githubusercontent.com:sub": "repo:my-org/my-app:ref:refs/heads/main"
  }
}
```

`aud` checks that the token was issued for AWS STS. `sub` checks where the run came from, and it is
the line that matters most. Without it, a workflow in *any* GitHub repository could assume your
role.

The workflow then requests the role. It runs only on pushes to `main`, which matches the `sub`
condition:

```yaml
on:
  push:
    branches: [main]
permissions:
  id-token: write   # lets the job request an OIDC token from GitHub
  contents: read
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: aws-actions/configure-aws-credentials@v6
        with:
          role-to-assume: arn:aws:iam::123456789012:role/github-deploy
          aws-region: ap-southeast-1
      - run: aws s3 cp ./dist s3://my-app-site/ --recursive
```

`id-token: write` allows the job to request the OIDC token. `configure-aws-credentials` exchanges
that token for temporary credentials and sets them for the steps that follow. No AWS secrets are
stored in GitHub.

Other CI systems that issue OIDC tokens can use the same idea, but the token claims and setup
differ. (I only cover GitHub here. Check your CI system's documentation for its AWS setup.)

## Fix 2: No Passwords in the File, Use Parameter Store or Secrets Manager

Store the password once in an AWS secret store, outside the repository. AWS has two:

- AWS Systems Manager Parameter Store, with `SecureString` parameters encrypted by KMS. This is
  enough for most passwords and tokens.
- AWS Secrets Manager. It is paid, and it adds automatic rotation, which is useful for database
  passwords.

CodeBuild reads both directly from the buildspec, so the build doesn't need a command to fetch
them:

```yaml
version: 0.2
env:
  parameter-store:
    DB_PASSWORD: /myapp/prod/db_password        # SecureString
  secrets-manager:
    API_TOKEN: myapp/prod/api:token              # <secret-id>:<json-key>
```

The name on the left becomes an environment variable. The value on the right is where CodeBuild
reads it from: a parameter name for Parameter Store, and `<secret-id>:<json-key>` for Secrets
Manager. During the build, `$DB_PASSWORD` and `$API_TOKEN` hold the real values.

The service role needs permission to read those two values and nothing else:
`ssm:GetParameters` on that parameter, and `secretsmanager:GetSecretValue` on that secret. If
the parameter or secret is encrypted with your own KMS key instead of the AWS-managed one, the
role also needs `kms:Decrypt` on that key.

Don't put secrets under `env: variables:`. The AWS buildspec reference strongly discourages it,
because those values show in plain text in the CodeBuild console and the AWS CLI.

### Where log masking stops working

CodeBuild hides values from `parameter-store` and `secrets-manager` in the build logs. The AWS
documentation is specific about how: it masks only the *exact* stored value. If a command changes
the secret before printing it, the output isn't masked:

```yaml
- echo "$DB_PASSWORD"                # masked in the log
- echo "$DB_PASSWORD" | base64       # NOT masked: a different string
- echo "user=admin:$DB_PASSWORD"     # NOT masked, per the docs: joined with other text
```

The same applies to reversing the value or changing its case. A connection string built from the
password is a joined value, so treat it the same way. If your build needs the Base64 form, store
the Base64 form. And don't print secrets on purpose, even "just to debug".

## Fix 3: No SSH from the Pipeline, Use Systems Manager

The `scp` line needs an SSH key stored with the pipeline, a public IP, and port 22 open to wherever
the pipeline runs. *AWS Systems Manager* (SSM) removes all of them. The SSM Agent runs on the
instance and connects out to AWS, so nothing has to connect in. The pipeline only needs the
instance ID and IAM permission to send a command:

```sh
aws ssm send-command \
  --instance-ids i-0123456789abcdef0 \
  --document-name AWS-RunShellScript \
  --parameters 'commands=["/opt/app/deploy.sh"]'
```

`AWS-RunShellScript` is an AWS-owned SSM document that runs shell commands on Linux. Here it runs
the instance's own deploy script.

On the instance side, two things must be true. The SSM Agent must be installed and running (AWS
preinstalls it on some of its AMIs; check the SSM Agent documentation for yours). The instance
needs an instance profile with the `AmazonSSMManagedInstanceCore` policy. And the agent needs an
outbound path to the Systems Manager endpoints: through a NAT gateway, or through VPC endpoints
if the instance is in a private subnet with no internet access.

> **Warning:** `send-command` returns as soon as the command is *sent*, not when it finishes. If
> `deploy.sh` fails on the instance, the build still passes. Wait for the result and fail the build
> if the command failed:
>
> ```sh
> CMD_ID=$(aws ssm send-command ... --query Command.CommandId --output text)
> aws ssm wait command-executed --command-id "$CMD_ID" --instance-id i-0123456789abcdef0
> ```
>
> The waiter exits with an error if the command doesn't succeed. `buildspec-secure.yaml` in the
> code folder does this.

With that in place, you can close port 22 completely, and AWS keeps a record of which commands were
sent to which instance. For an interactive shell, use *Session Manager*
(`aws ssm start-session --target i-0123...`) instead of SSH. For full deployments with rollback,
AWS CodeDeploy is the next step up.

`buildspec-secure.yaml` in the code folder puts all three fixes together.

## Catch Secrets with a Scanner

The fixes above remove the *need* for secrets in files. A scanner catches the ones that slip in
anyway. `scan.sh` runs [gitleaks](https://github.com/gitleaks/gitleaks) in Docker against a
repository's Git history. I copied the insecure buildspec into a test
repository as `buildspec.yaml`, committed it, and scanned it. The output is trimmed to the lines
that matter:

```sh
./scan.sh /path/to/repo
```

```text
Finding:     AWS_SECRET_ACCESS_KEY: 7Ws9xPq1Vn2bLk8Rt4Yz6Hj3Mc5Fg0Ds2Ae7Kp9Q
RuleID:      generic-api-key
File:        buildspec.yaml
Line:        6
INF 1 commits scanned.
WRN leaks found: 1
```

gitleaks found the secret access key and exited with code 1, so a CI job running it would fail.

It missed the other two. The access key ID got through because my made-up ID doesn't match the
format of a real one. The password `Sup3rS3cret!` got through too. (I didn't trace which rule
skipped it. My guess is that it is too short and too predictable for the generic rule.) So one of
three secrets was caught.

A scanner is a safety net, not a guarantee. Run it in CI and before commits, and keep using Fixes 1
to 3. GitHub also offers secret scanning and push protection for repositories, which can block a
push that contains a known secret format.

## If a Secret Leaks Anyway

Act in this order:

1. Disable the credential first. Deactivate the access key in IAM, or change the password. Then
   investigate. Removing the secret from Git doesn't help at this point: it's already in history
   and possibly in other people's clones.
2. Check what it was used for. Search AWS CloudTrail for API calls made with that access key ID,
   and check the bill for new resources in every Region.
3. Replace it with one of the fixes above, so there's no new key to leak.
4. Clean the Git history only after that. Anyone who already cloned the repository still has the
   old version.

## Checklist

Before you merge a pipeline change:

- No AWS access keys in the file or the CI settings: use a role (CodeBuild) or OIDC (GitHub Actions).
- No passwords or tokens in the file or under `env: variables:`: use `parameter-store` or
  `secrets-manager`.
- No SSH keys or server IPs: use Systems Manager Run Command or Session Manager.
- The role has only the permissions this pipeline needs.
- A secret scanner runs on every push.

## Summary

- Pipeline files leak through the repository, build logs, and Git history, so they must hold no
  secrets.
- Give pipelines AWS access through IAM roles: a service role for CodeBuild, and OIDC for GitHub
  Actions, limited by repository and branch.
- Read passwords at build time with `parameter-store` and `secrets-manager`. Logs mask only the exact
  stored value, so never transform and print a secret.
- Deploy with Systems Manager instead of SSH, and close port 22.
- Scan every commit with a tool like gitleaks, but don't rely on it alone. My test caught one of
  three secrets.

Next step: search your repositories for `AWS_SECRET_ACCESS_KEY` and `password:` today, and replace
the first one you find with a role or a Parameter Store reference.

## Resources

- [Build specification reference for CodeBuild](https://docs.aws.amazon.com/codebuild/latest/userguide/build-spec-ref.html), including `parameter-store`, `secrets-manager`, and log masking
- [Configuring OpenID Connect in Amazon Web Services](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-aws), GitHub Docs
- [aws-actions/configure-aws-credentials](https://github.com/aws-actions/configure-aws-credentials)
- [AWS Systems Manager Run Command](https://docs.aws.amazon.com/systems-manager/latest/userguide/run-command.html) and [Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html)
- [gitleaks](https://github.com/gitleaks/gitleaks)
