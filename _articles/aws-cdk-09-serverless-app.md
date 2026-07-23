---
layout: post
title: "A Serverless App, End to End"
series: "AWS CDK"
series_url: /aws-cdk-series/
part: 9
date: 2023-04-28
author: Quan Huynh
tags: [aws, cdk, iac, go, serverless, lambda]
image: /assets/images/posts/aws-cdk-09-serverless-app/cover.svg
---

This is the final post of the series, and we'll use it to tie everything together.
We'll build a complete, working serverless API — **API Gateway → Lambda → DynamoDB**
— using the CDK skills we've collected along the way. By the end you'll have deployed
a real HTTP endpoint backed by real AWS services, all from Go.

## What we're building

A tiny "questions" service with one job: accept a question over HTTP and store it.

```
Client ──HTTP──> API Gateway ──> Lambda (Go) ──> DynamoDB
```

Serverless is a natural fit for CDK: there are no servers to manage, you pay per
request, and CDK wires the pieces together — permissions included — in a few lines.

## The Lambda handler

First the application code. This is an ordinary Go program that reads a JSON body,
gives it an ID, and writes it to DynamoDB. Put it in `lambda/main.go`:

```go
package main

import (
  "context"
  "encoding/json"
  "os"

  "github.com/aws/aws-lambda-go/events"
  "github.com/aws/aws-lambda-go/lambda"
  "github.com/aws/aws-sdk-go-v2/aws"
  "github.com/aws/aws-sdk-go-v2/config"
  "github.com/aws/aws-sdk-go-v2/feature/dynamodb/attributevalue"
  "github.com/aws/aws-sdk-go-v2/service/dynamodb"
  "github.com/google/uuid"
)

type Question struct {
  ID    string `json:"id" dynamodbav:"id"`
  Title string `json:"title" dynamodbav:"title"`
}

var (
  client *dynamodb.Client
  table  = os.Getenv("TABLE_NAME")
)

func handler(ctx context.Context, req events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
  var q Question
  if err := json.Unmarshal([]byte(req.Body), &q); err != nil {
    return events.APIGatewayProxyResponse{StatusCode: 400, Body: "invalid body"}, nil
  }
  q.ID = uuid.NewString()

  item, err := attributevalue.MarshalMap(q)
  if err != nil {
    return events.APIGatewayProxyResponse{StatusCode: 500}, err
  }

  _, err = client.PutItem(ctx, &dynamodb.PutItemInput{
    TableName: aws.String(table),
    Item:      item,
  })
  if err != nil {
    return events.APIGatewayProxyResponse{StatusCode: 500}, err
  }

  body, _ := json.Marshal(q)
  return events.APIGatewayProxyResponse{
    StatusCode: 201,
    Headers:    map[string]string{"Content-Type": "application/json"},
    Body:       string(body),
  }, nil
}

func main() {
  cfg, err := config.LoadDefaultConfig(context.Background())
  if err != nil {
    panic(err)
  }
  client = dynamodb.NewFromConfig(cfg)
  lambda.Start(handler)
}
```

Notice the handler reads its table name from an environment variable — it doesn't
hardcode anything. CDK will inject that value for us.

## The infrastructure

Now the CDK Stack. It creates the table, the function, and the API — and, crucially,
grants the function permission to use the table. `main.go`:

```go
package main

import (
  "github.com/aws/aws-cdk-go/awscdk/v2"
  "github.com/aws/aws-cdk-go/awscdk/v2/awsapigateway"
  "github.com/aws/aws-cdk-go/awscdk/v2/awsdynamodb"
  "github.com/aws/aws-cdk-go/awscdk/v2/awslambda"
  "github.com/aws/constructs-go/constructs/v10"
  "github.com/aws/jsii-runtime-go"
)

type ServerlessStackProps struct {
  awscdk.StackProps
}

func NewServerlessStack(scope constructs.Construct, id string, props *ServerlessStackProps) awscdk.Stack {
  var sprops awscdk.StackProps
  if props != nil {
    sprops = props.StackProps
  }
  stack := awscdk.NewStack(scope, &id, &sprops)

  // The data store.
  table := awsdynamodb.NewTable(stack, jsii.String("Questions"), &awsdynamodb.TableProps{
    PartitionKey: &awsdynamodb.Attribute{
      Name: jsii.String("id"),
      Type: awsdynamodb.AttributeType_STRING,
    },
    BillingMode:   awsdynamodb.BillingMode_PAY_PER_REQUEST,
    RemovalPolicy: awscdk.RemovalPolicy_DESTROY,
  })

  // The Go handler. Build a `bootstrap` binary into ./lambda first (see below).
  fn := awslambda.NewFunction(stack, jsii.String("Handler"), &awslambda.FunctionProps{
    Runtime:      awslambda.Runtime_PROVIDED_AL2023(),
    Architecture: awslambda.Architecture_ARM_64(),
    Handler:      jsii.String("bootstrap"),
    Code:         awslambda.Code_FromAsset(jsii.String("lambda"), nil),
    Environment: &map[string]*string{
      "TABLE_NAME": table.TableName(),
    },
  })

  // Least-privilege: this function, this table, read + write only.
  table.GrantReadWriteData(fn)

  // Expose it over HTTP.
  awsapigateway.NewLambdaRestApi(stack, jsii.String("Api"), &awsapigateway.LambdaRestApiProps{
    Handler: fn,
  })

  return stack
}

func main() {
  defer jsii.Close()

  app := awscdk.NewApp(nil)
  NewServerlessStack(app, "ServerlessStack", &ServerlessStackProps{})
  app.Synth(nil)
}
```

Two lines do a surprising amount of work:

- `table.GrantReadWriteData(fn)` writes the exact IAM policy the function needs to
  read and write this one table — no more, no less. This is the least-privilege
  practice from the previous post, in a single call.
- `NewLambdaRestApi` creates an API Gateway REST API that forwards every request to
  our function. CDK also sets up the invoke permission so API Gateway is allowed to
  call the Lambda.

Also notice `"TABLE_NAME": table.TableName()`. We never type the table's real name —
CDK generates it and passes it to the function. The infrastructure and the code stay
in sync automatically.

## Building the Go Lambda

Go Lambdas run as a custom runtime, which expects a binary named `bootstrap`. Build
it for the Lambda architecture before you deploy:

```bash
cd lambda
GOOS=linux GOARCH=arm64 go build -tags lambda.norpc -o bootstrap .
cd ..
```

`Code_FromAsset(jsii.String("lambda"), ...)` then packages that folder as the
function's code. (For a smoother workflow you can use the `awscdkawslambdagoalpha`
construct, which builds the Go binary for you at synth time.)

## Deploy and test

Deploy the Stack:

```bash
go mod tidy
cdk deploy
```

When it finishes, CDK prints the API URL as an output. Send it a question:

```bash
curl -X POST https://<api-id>.execute-api.us-west-2.amazonaws.com/prod/ \
  -H 'Content-Type: application/json' \
  -d '{"title": "What is AWS CDK?"}'
```

You'll get back the stored item, complete with the generated `id`:

```json
{ "id": "3f2a...", "title": "What is AWS CDK?" }
```

Check the DynamoDB console and you'll see the row. A full HTTP API, a compute layer,
and a database — defined in one file of Go, with permissions handled for you.

When you're done, tear it all down:

```bash
cdk destroy
```

Because we set `RemovalPolicy_DESTROY` on the table, everything is cleaned up and you
won't be charged for idle resources.

## Wrapping up the series

Over these nine posts we went from "what is infrastructure as code?" to deploying a
complete serverless application:

- We learned **what CDK is** and why writing infrastructure in a real language beats
  hand-writing templates.
- We met the core building blocks — **App, Stack, and Construct** — and the
  **L1/L2/L3** construct layers.
- We designed a **multi-stack application** and learned to **share constructs**
  across stacks.
- We made our code production-ready: **testing**, **CI/CD**, and a set of
  **best practices**.
- And finally we shipped a **serverless API** end to end.

The big idea to take with you is this: with CDK, your infrastructure is software. You
can test it, review it, refactor it, and reuse it — with all the tools and habits you
already have as an engineer. Everything in this series is on
[GitHub](https://github.com/VersusControl/devops-vn-blog/tree/main/_resource/aws-cdk-series);
clone it, deploy it, and make it your own.

Thanks for following along — now go build something.
