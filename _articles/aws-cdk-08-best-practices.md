---
layout: post
title: "Production Best Practices"
series: "AWS CDK"
series_url: /aws-cdk-series/
part: 8
date: 2023-04-21
author: Quan Huynh
tags: [aws, cdk, iac, go]
image: /assets/images/posts/aws-cdk-08-best-practices/cover.svg
---

By now you can build, test, and deploy infrastructure with CDK. This post is about
the habits that separate a demo from a codebase you'll happily maintain for years.
None of these are hard — they just need to be deliberate.

## 1. Tag everything, in one place

Tags drive cost allocation, ownership, and automation. Instead of tagging each
resource by hand, tag the whole Stack (or App) once and let CDK propagate:

```go
awscdk.Tags_Of(stack).Add(jsii.String("Project"), jsii.String("question-service"), nil)
awscdk.Tags_Of(stack).Add(jsii.String("ManagedBy"), jsii.String("cdk"), nil)
```

Every resource that supports tags inherits these. When the finance team asks what a
service costs, you'll have an answer.

## 2. Be deliberate about removal policy

By default, deleting a Stack deletes its resources. That's what you want for a scratch
environment — and exactly what you *don't* want for a production database. Make the
choice explicit:

```go
awss3.NewBucket(stack, jsii.String("Data"), &awss3.BucketProps{
  Versioned:     jsii.Bool(true),
  RemovalPolicy: awscdk.RemovalPolicy_RETAIN,
})
```

`RETAIN` keeps the resource even if the Stack is deleted. Use it for anything
stateful (databases, buckets with data). Use `DESTROY` for throwaway resources so
your test accounts stay clean.

## 3. Never hardcode secrets

Earlier in the series we used `SecretValue_UnsafePlainText` to keep examples simple.
The name is a warning: the value ends up in the synthesized template in plaintext.
For real systems, let CDK generate a secret in Secrets Manager and hand the
*reference* to the resource:

```go
awsrds.NewDatabaseInstance(stack, jsii.String("Postgres"), &awsrds.DatabaseInstanceProps{
  Engine: awsrds.DatabaseInstanceEngine_Postgres(&awsrds.PostgresInstanceEngineProps{
    Version: awsrds.PostgresEngineVersion_VER_16(),
  }),
  InstanceType: awsec2.NewInstanceType(jsii.String("t3.micro")),
  Credentials:  awsrds.Credentials_FromGeneratedSecret(jsii.String("question"), nil),
  Vpc:          vpc,
})
```

The password is generated, stored in Secrets Manager, and rotated on your terms. It
never appears in your code or your CloudFormation template.

## 4. Grant least privilege with `grant` methods

L2 constructs come with `grant*` helpers that write the minimal IAM policy for you.
Prefer them over hand-written policies:

```go
table.GrantReadWriteData(fn)   // only this function, only this table
```

This is both safer and less code than crafting an IAM policy document by hand. If you
later remove the function, the permission goes with it.

## 5. Keep environments configuration, not copies

Resist the urge to copy a Stack per environment. Pass the differences in as
parameters instead:

```go
type ServiceProps struct {
  awscdk.StackProps
  InstanceSize string
  MinCapacity  float64
}
```

Then create `dev` and `prod` from the *same* Stack with different props. One
definition, no drift between environments.

## 6. Pin versions

Pin your CDK library version in `go.mod` and the language versions in your pipeline.
A construct's defaults can change between releases; pinning means an upgrade is a
deliberate, reviewable event — not a surprise on your next deploy.

## 7. Let `cdk diff` be your seatbelt

Before every deploy, read the diff. CDK marks destructive changes clearly. If you see
a resource being *replaced* when you only meant to tweak a property, stop and look —
a replacement can mean data loss. In a pipeline, surface the diff on every pull
request so a human always sees it.

## Conclusion

Good CDK code isn't about clever abstractions — it's about being deliberate:
consistent tags, explicit removal policies, generated secrets, least-privilege
grants, parameterized environments, pinned versions, and always reading the diff.
Adopt these and your infrastructure stays boring, which in operations is the highest
compliment.

We've covered testing, delivery, and best practices. In the
[final post]({{ '/aws-cdk-series/' | relative_url }}) we'll put it all together and
build a complete **serverless application** end to end — API Gateway, Lambda, and
DynamoDB — with everything we've learned.
