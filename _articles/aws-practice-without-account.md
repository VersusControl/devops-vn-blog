---
layout: post
title: "Practice AWS for Free with LocalStack — No Account Needed"
subtitle: "Run a local AWS environment on your machine so you can learn hands-on without a credit card or surprise bills."
date: 2023-09-29
author: Quan Huynh
tags: [aws, localstack]
image: /assets/images/posts/aws-practice-without-account/cover.png
---

One of the biggest hurdles for anyone learning AWS is the sign-up wall: you need a
credit card, and one misconfigured resource can leave you with a surprise bill. The
good news is you can practice AWS hands-on without creating an account at all. This is
ideal for beginners who just want to learn — but it is **not** recommended for
production.

The trick is to emulate an AWS environment locally using a tool called
[LocalStack](https://localstack.cloud/). The steps are as follows.

Run LocalStack with Docker:

```bash
docker run --rm -it -p 4566:4566 -p 4510-4559:4510-4559 localstack/localstack
```

Install the [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
and run the `configure` command, entering the values below:

```bash
aws configure
```

```
AWS Access Key ID: test
AWS Secret Access Key: test
Default region name: us-east-1
Default output format [None]
```

Finally, when running an AWS command, add the `--endpoint-url` option:

```bash
aws --endpoint-url=http://localhost:4566
```

For example, create an S3 bucket:

```bash
aws --endpoint-url=http://localhost:4566 s3api create-bucket --bucket localstack
```

```json
{
  "Location": "/localstack"
}
```

If you'd like a UI, follow the guide here:
[Resource Browser](https://docs.localstack.cloud/user-guide/web-application/resource-browser/).
It still has some limitations, but it's a very handy tool if you need to practice
AWS without being able to create an account. LocalStack can emulate more than 60
AWS services — plenty to practice with.
