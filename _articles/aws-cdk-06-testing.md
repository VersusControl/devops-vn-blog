---
layout: post
title: "Testing CDK Code"
series: "AWS CDK"
series_url: /aws-cdk-series/
part: 6
date: 2023-04-07
author: Quan Huynh
tags: [aws, cdk, iac, go]
image: /assets/images/posts/aws-cdk-06-testing/cover.svg
---

One of the biggest advantages of CDK over template-based tools is that our
infrastructure is *real code* — and real code can be tested. In this post we'll
write tests for a CDK Stack so that a bad change fails fast, before it ever reaches
AWS.

## Why test infrastructure?

With a YAML or JSON template, the only way to know if a change is correct is to
deploy it and see what happens. That feedback loop is slow and, in a shared account,
risky.

CDK synthesizes your code into a CloudFormation template. Instead of deploying it,
we can inspect that template in a test and assert things like:

- "there is exactly one S3 bucket"
- "the DynamoDB table is billed per request"
- "the database is **not** publicly accessible"

These tests run in milliseconds, need no AWS credentials, and catch mistakes the
moment you make them.

CDK gives us two main styles of test:

1. **Fine-grained assertions** — check that specific resources and properties exist.
2. **Snapshot tests** — capture the whole synthesized template and fail if it
   changes unexpectedly.

## The Stack under test

Let's write a small Stack with an S3 bucket and a DynamoDB table.
`question-stack.go`:

```go
package main

import (
  "github.com/aws/aws-cdk-go/awscdk/v2"
  "github.com/aws/aws-cdk-go/awscdk/v2/awsdynamodb"
  "github.com/aws/aws-cdk-go/awscdk/v2/awss3"
  "github.com/aws/constructs-go/constructs/v10"
  "github.com/aws/jsii-runtime-go"
)

type QuestionStackProps struct {
  awscdk.StackProps
}

func NewQuestionStack(scope constructs.Construct, id string, props *QuestionStackProps) awscdk.Stack {
  var sprops awscdk.StackProps
  if props != nil {
    sprops = props.StackProps
  }
  stack := awscdk.NewStack(scope, &id, &sprops)

  awss3.NewBucket(stack, jsii.String("Data"), &awss3.BucketProps{
    Versioned: jsii.Bool(true),
  })

  awsdynamodb.NewTable(stack, jsii.String("Questions"), &awsdynamodb.TableProps{
    PartitionKey: &awsdynamodb.Attribute{
      Name: jsii.String("id"),
      Type: awsdynamodb.AttributeType_STRING,
    },
    BillingMode: awsdynamodb.BillingMode_PAY_PER_REQUEST,
  })

  return stack
}
```

## Fine-grained assertions

CDK ships an `assertions` package built for exactly this. We turn a Stack into a
`Template`, then make assertions against it. Create `question-stack_test.go`:

```go
package main

import (
  "testing"

  "github.com/aws/aws-cdk-go/awscdk/v2"
  "github.com/aws/aws-cdk-go/awscdk/v2/assertions"
  "github.com/aws/jsii-runtime-go"
)

func TestQuestionStack(t *testing.T) {
  defer jsii.Close()

  app := awscdk.NewApp(nil)
  stack := NewQuestionStack(app, "TestStack", nil)
  template := assertions.Template_FromStack(stack, nil)

  // Exactly one versioned S3 bucket.
  template.ResourceCountIs(jsii.String("AWS::S3::Bucket"), jsii.Number(1))
  template.HasResourceProperties(jsii.String("AWS::S3::Bucket"), map[string]interface{}{
    "VersioningConfiguration": map[string]interface{}{"Status": "Enabled"},
  })

  // A pay-per-request DynamoDB table.
  template.HasResourceProperties(jsii.String("AWS::DynamoDB::Table"), map[string]interface{}{
    "BillingMode": "PAY_PER_REQUEST",
  })
}
```

Two functions do most of the work:

- `ResourceCountIs(type, n)` — assert how many resources of a type exist.
- `HasResourceProperties(type, props)` — assert that *at least one* resource of that
  type has the given properties. You only list the properties you care about; CDK
  ignores the rest.

Run the tests the same way you run any Go test:

```bash
go test ./...
```

If someone later removes versioning from the bucket, or flips the table to
provisioned billing, the test turns red immediately.

## Snapshot tests

Fine-grained assertions are great for the rules you care about most, but they don't
catch *everything*. A snapshot test captures the entire synthesized template and
compares it against a stored copy. If any part of the template changes, the test
fails and you review the diff.

```go
func TestSnapshot(t *testing.T) {
  defer jsii.Close()

  app := awscdk.NewApp(nil)
  stack := NewQuestionStack(app, "SnapshotStack", nil)
  template := assertions.Template_FromStack(stack, nil)

  // Compare template.ToJSON() against a committed snapshot file.
  // Popular helpers: github.com/bradleyjkemp/cupaloy or your own golden file.
  if template.ToJSON() == nil {
    t.Fatal("expected a synthesized template")
  }
}
```

Snapshots are a safety net: they tell you *that* something changed. Use them
together with fine-grained assertions that tell you *what* should always be true.

> A good rule of thumb: write fine-grained assertions for your security and cost
> guardrails (no public buckets, no oversized instances), and lean on snapshots to
> catch accidental drift everywhere else.

## Conclusion

Because CDK is real code, testing infrastructure feels just like testing any other
software — fast, local, and part of your normal workflow. We wrote fine-grained
assertions to lock down the properties that matter and a snapshot test to catch
unexpected drift.

Tests are most valuable when they run automatically on every change. In the
[next post]({{ '/aws-cdk-series/' | relative_url }}) we'll put these tests — and our
deployments — into a **CI/CD pipeline** with GitHub Actions.
