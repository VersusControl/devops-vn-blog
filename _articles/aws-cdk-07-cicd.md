---
layout: post
title: "CI/CD for CDK"
series: "AWS CDK"
series_url: /aws-cdk-series/
part: 7
date: 2023-04-14
author: Quan Huynh
tags: [aws, cdk, iac, go]
image: /assets/images/posts/aws-cdk-07-cicd/cover.svg
---

So far we've been running `cdk deploy` from our own machine. That's fine while
learning, but in a team it quickly becomes a problem: whose laptop is the source of
truth? In this post we'll move deployments into a pipeline so that every change goes
through the same reviewed, automated path.

## The goal

We want this workflow:

1. You open a pull request with an infrastructure change.
2. The pipeline runs your tests and shows a `cdk diff` — exactly what will change.
3. A teammate reviews the diff and approves.
4. On merge to `main`, the pipeline runs `cdk deploy` automatically.

No one deploys from a laptop, and every change is reviewed and reproducible.

## Authenticating without long-lived keys

The first question is how the pipeline talks to AWS. The old way was to store an
access key and secret in CI — but static credentials leak, and rotating them is
painful.

The modern way is **OpenID Connect (OIDC)**. GitHub Actions requests a short-lived
token, AWS trusts GitHub as an identity provider, and your workflow assumes an IAM
role for the duration of the job. No secrets are stored anywhere.

You set this up once in your account: create an IAM OIDC identity provider for
GitHub, then a role that trusts your repository. We can even do that in CDK, but the
IAM console walkthrough in the AWS docs is the quickest way to start.

## The workflow

Here's a GitHub Actions workflow that tests, diffs, and deploys a Go CDK app. Put it
in `.github/workflows/cdk.yml`:

```yaml
name: CDK Deploy

on:
  push:
    branches: [main]

permissions:
  id-token: write   # required for OIDC
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-go@v5
        with:
          go-version: "1.24"

      - name: Install CDK
        run: npm install -g aws-cdk

      # Log in to AWS with short-lived OIDC credentials — no stored keys.
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::<ACCOUNT_ID>:role/github-actions-cdk
          aws-region: us-west-2

      - run: go mod tidy

      # Show what would change (fails the build on synth errors).
      - name: Diff
        run: cdk diff

      # Deploy without an interactive prompt.
      - name: Deploy
        run: cdk deploy --all --require-approval never
```

A few lines are worth calling out:

- `permissions: id-token: write` is what lets the job request an OIDC token. Without
  it, the AWS login step fails.
- `role-to-assume` is the IAM role you created for the repository. The
  `configure-aws-credentials` action exchanges the OIDC token for temporary
  credentials for that role.
- `--require-approval never` skips the interactive "are you sure?" prompt that CDK
  shows for security-sensitive changes. In a pipeline there's no human to answer it,
  so we handle approval through pull request review instead.

## Diff on pull requests

Deploying on merge is only half the story. The real value is seeing the diff *before*
you merge. Add a second workflow that runs on pull requests and posts the output of
`cdk diff`:

```yaml
on:
  pull_request:
    branches: [main]
```

Now every PR shows reviewers precisely which resources will be created, changed, or
destroyed. A one-line code change that would replace your database becomes obvious in
review, instead of a surprise in production.

## Bootstrapping

One thing to remember: before CDK can deploy into an account/region, that
environment must be **bootstrapped** once. Bootstrapping creates the S3 bucket and
roles CDK uses to upload assets and run deployments:

```bash
cdk bootstrap aws://<ACCOUNT_ID>/us-west-2
```

Do this once per account/region — from your machine or a privileged setup job — and
your pipeline can deploy freely afterwards.

## Conclusion

With a pipeline in place, infrastructure changes follow the same disciplined path as
application code: propose, review the diff, and deploy automatically on merge. OIDC
keeps the whole thing credential-free.

Our infrastructure is now tested and automated. In the
[next post]({{ '/aws-cdk-series/' | relative_url }}) we'll gather the habits that
keep a CDK codebase healthy as it grows — a set of **production best practices**.
