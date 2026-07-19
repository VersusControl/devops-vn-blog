---
layout: post
title: "Practicing AWS Without Creating an Account"
date: 2023-09-29
author: Quan Huynh
tags: [aws, localstack]
image: /assets/images/posts/aws-practice-without-account/cover.png
---

Here's how to practice AWS without creating an account, so you avoid getting
charged. This is great for beginners who want to learn AWS. It is **not**
recommended for production.

To do this, we'll emulate an AWS environment locally using a tool called
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
