---
layout: post
title: "Hands-On: Designing and Building Infrastructure for a Q&A App"
series: "AWS CDK"
series_url: /aws-cdk-series/
part: 3
date: 2023-03-14
author: Quan Huynh
tags: [aws, cdk, iac, go]
image: /assets/images/posts/aws-cdk-03-design-build-qa-infrastructure/cover.png
---

In the previous post we learned the core components of CDK and built infrastructure
for a simple Q&A app. In this post we'll learn how to expand that infrastructure.

## Design

At the end of the previous post our infrastructure looked like this:

![Current Q&A infrastructure]({{ '/assets/images/posts/aws-cdk-03-design-build-qa-infrastructure/qa-current-infra.png' | relative_url }})

Currently, to fetch the list of questions and answers, the user calls the server
(EC2), and the EC2 queries the database (RDS) directly. Usually, once a user
creates a question or answer, it rarely changes. So querying RDS repeatedly for
the same result wastes resources. On top of that, querying results directly from
RDS is fairly slow.

![Problem: querying RDS directly]({{ '/assets/images/posts/aws-cdk-03-design-build-qa-infrastructure/problem-direct-rds.png' | relative_url }})

So we add a cache layer between EC2 and RDS to speed up reads and reduce load on
RDS. AWS provides AWS ElastiCache for caching.

![Adding a cache layer]({{ '/assets/images/posts/aws-cdk-03-design-build-qa-infrastructure/add-cache-layer.png' | relative_url }})

Besides caching, ElastiCache also improves the application's high availability. For
example, if RDS dies, users can't write data but can still read it.

![Cache improves high availability]({{ '/assets/images/posts/aws-cdk-03-design-build-qa-infrastructure/cache-high-availability.png' | relative_url }})

However, if our EC2 dies, users can't access the app at all. So to improve
availability, we separate the EC2 for reading and writing data.

![Separating read and write]({{ '/assets/images/posts/aws-cdk-03-design-build-qa-infrastructure/separate-read-write.png' | relative_url }})

The current system looks fine, but it has a weakness: if users write continuously
to RDS at a given time, and because our read data lives in ElastiCache, we'd have
to update ElastiCache continuously. For a Q&A app, real-time updates like that
aren't necessary → this wastes ElastiCache resources.

We can update ElastiCache's read data on an interval, once every 5 minutes — all
the data written to RDS within 5 minutes gets updated at once. This avoids wasting
ElastiCache resources.

![Periodic cache update]({{ '/assets/images/posts/aws-cdk-03-design-build-qa-infrastructure/periodic-cache-update.png' | relative_url }})

Instead of querying RDS and reading data over 5 minutes, we can simplify this work
as follows:

1. Save the data into RDS
2. Take the ID of that data and store it in a separate temporary database

To show you how to create more AWS services with CDK, I'll use DynamoDB as the
temporary database.

![DynamoDB as temporary store]({{ '/assets/images/posts/aws-cdk-03-design-build-qa-infrastructure/dynamodb-temp.png' | relative_url }})

To make future expansion and management easier, we split each related area into a
separate Stack in CDK.

![Splitting into stacks]({{ '/assets/images/posts/aws-cdk-03-design-build-qa-infrastructure/split-into-stacks.png' | relative_url }})

## Preparation

Create the directory and initialize the app:

```bash
mkdir question-service && cd question-service
```

```bash
cdk init app --language go
```

```bash
go get
```

Delete all the code in `question-service.go` and paste in the following:

```go
package main

import (
  "os"

  "github.com/aws/aws-cdk-go/awscdk/v2"
  "github.com/aws/jsii-runtime-go"
)

func main() {
  defer jsii.Close()

  // App
  app := awscdk.NewApp(nil)

  app.Synth(nil)
}

func env() *awscdk.Environment {
  return &awscdk.Environment{
    Account: jsii.String(os.Getenv("CDK_DEFAULT_ACCOUNT")),
    Region:  jsii.String(os.Getenv("CDK_DEFAULT_REGION")),
  }
}
```

Create a directory named `stack`:

```bash
mkdir stack
```

Create the following 3 files inside the `stack` directory:

```
├── cache-stack.go
├── insert-stack.go
└── worker-stack.go
```

The current directory structure:

```
...
├── go.mod
├── go.sum
├── question-service.go
├── question-service_test.go
└── stack
    ├── cache-stack.go
    ├── insert-stack.go
    └── worker-stack.go
```

Each file in the `stack` directory corresponds to one Stack in CDK. Paste the
following code into each file.

`insert-stack.go`:

```go
package stack

import (
  "github.com/aws/aws-cdk-go/awscdk/v2"
  "github.com/aws/constructs-go/constructs/v10"
)

type QuestionInsertStackProps struct {
  awscdk.StackProps
}

func NewQuestionInsertStack(scope constructs.Construct, id string, props *QuestionInsertStackProps) awscdk.Stack {
  var sprops awscdk.StackProps
  if props != nil {
    sprops = props.StackProps
  }
  stack := awscdk.NewStack(scope, &id, &sprops)

  return stack
}
```

`cache-stack.go`:

```go
package stack

import (
  "github.com/aws/aws-cdk-go/awscdk/v2"
  "github.com/aws/constructs-go/constructs/v10"
)

type QuestionCacheStackProps struct {
  awscdk.StackProps
}

func NewQuestionCacheStack(scope constructs.Construct, id string, props *QuestionCacheStackProps) awscdk.Stack {
  var sprops awscdk.StackProps
  if props != nil {
    sprops = props.StackProps
  }
  stack := awscdk.NewStack(scope, &id, &sprops)

  return stack
}
```

`worker-stack.go`:

```go
package stack

import (
  "github.com/aws/aws-cdk-go/awscdk/v2"
  "github.com/aws/constructs-go/constructs/v10"
)

type QuestionWorkerStackProps struct {
  awscdk.StackProps
}

func NewQuestionWorkerStack(scope constructs.Construct, id string, props *QuestionWorkerStackProps) awscdk.Stack {
  var sprops awscdk.StackProps
  if props != nil {
    sprops = props.StackProps
  }
  stack := awscdk.NewStack(scope, &id, &sprops)

  return stack
}
```

All the code is the same, only the function names differ. Back in
`question-service.go`, add the following code:

```go
...

import (
  "os"

  "question-service/stack"

  "github.com/aws/aws-cdk-go/awscdk/v2"
  "github.com/aws/jsii-runtime-go"
)

func main() {
  defer jsii.Close()

  // App
  app := awscdk.NewApp(nil)

  // Question Cache Stack
  stack.NewQuestionCacheStack(app, "QuestionCacheStack", &stack.QuestionCacheStackProps{
    StackProps: awscdk.StackProps{
      Env: env(),
    },
  })

  // Question Worker Stack
  stack.NewQuestionWorkerStack(app, "QuestionWorkerStack", &stack.QuestionWorkerStackProps{
    StackProps: awscdk.StackProps{
      Env: env(),
    },
  })

  // Question Insert Stack
  stack.NewQuestionInsertStack(app, "QuestionInsertStack", &stack.QuestionInsertStackProps{
    StackProps: awscdk.StackProps{
      Env: env(),
    },
  })

  app.Synth(nil)
}

...
```

When a CDK app has multiple Stacks, list all of them with:

```bash
cdk list
```

```
QuestionCacheStack
QuestionInsertStack
QuestionWorkerStack
```

Next we'll start writing the code.

## Write Code

**QuestionInsertStack**

We start with `QuestionInsertStack`, since this is the Stack we created in the
previous post.

![Insert stack]({{ '/assets/images/posts/aws-cdk-03-design-build-qa-infrastructure/insert-stack.png' | relative_url }})

Open `insert-stack.go` and paste in the following:

```go
package stack

import (
  "github.com/aws/aws-cdk-go/awscdk/v2"
  "github.com/aws/aws-cdk-go/awscdk/v2/awsec2"
  "github.com/aws/aws-cdk-go/awscdk/v2/awsrds"
  "github.com/aws/constructs-go/constructs/v10"
  "github.com/aws/jsii-runtime-go"
)

type QuestionInsertStackProps struct {
  awscdk.StackProps
}

func NewQuestionInsertStack(scope constructs.Construct, id string, props *QuestionInsertStackProps) awscdk.Stack {
  var sprops awscdk.StackProps
  if props != nil {
    sprops = props.StackProps
  }
  stack := awscdk.NewStack(scope, &id, &sprops)

  // VPC Construct
  vpc := awsec2.Vpc_FromLookup(stack, jsii.String("DefaultVPC"), &awsec2.VpcLookupOptions{IsDefault: jsii.Bool(true)})

  // RDS Construct
  awsrds.NewDatabaseInstance(stack, jsii.String("Postgres"), &awsrds.DatabaseInstanceProps{
    Engine:       awsrds.DatabaseInstanceEngine_POSTGRES(),
    InstanceType: awsec2.NewInstanceType(jsii.String("t3.micro")),
    Credentials: awsrds.Credentials_FromPassword(
      jsii.String("question"),
      awscdk.NewSecretValue("question", &awscdk.IntrinsicProps{}),
    ),
    PubliclyAccessible: jsii.Bool(true),
    VpcSubnets:         &awsec2.SubnetSelection{SubnetType: awsec2.SubnetType_PUBLIC},
    Vpc:                vpc,
  })

  // EC2 Construct
  awsec2.NewInstance(stack, jsii.String("Server"), &awsec2.InstanceProps{
    InstanceType: awsec2.NewInstanceType(jsii.String("t3.micro")),
    MachineImage: awsec2.NewAmazonLinuxImage(&awsec2.AmazonLinuxImageProps{
      Generation: awsec2.AmazonLinuxGeneration_AMAZON_LINUX_2,
    }),
    Vpc: vpc,
  })

  return stack
}
```

Generate CloudFormation to preview the resources. With a multi-Stack app, add the
Stack name after the `synth` command:

```bash
cdk synth QuestionInsertStack
```

**QuestionCacheStack**

Next we work on `QuestionCacheStack`.

![Cache stack]({{ '/assets/images/posts/aws-cdk-03-design-build-qa-infrastructure/cache-stack.png' | relative_url }})

`QuestionCacheStack` includes three Constructs: VPC, EC2, and ElastiCache. VPC and
EC2 are Constructs we're familiar with. Open `cache-stack.go` and first paste the
code to create the VPC and EC2 Constructs:

```go
package stack

import (
  "github.com/aws/aws-cdk-go/awscdk/v2"
  "github.com/aws/aws-cdk-go/awscdk/v2/awsec2"
  "github.com/aws/constructs-go/constructs/v10"
  "github.com/aws/jsii-runtime-go"
)

type QuestionCacheStackProps struct {
  awscdk.StackProps
}

func NewQuestionCacheStack(scope constructs.Construct, id string, props *QuestionCacheStackProps) awscdk.Stack {
  var sprops awscdk.StackProps
  if props != nil {
    sprops = props.StackProps
  }
  stack := awscdk.NewStack(scope, &id, &sprops)

  // VPC Construct
  vpc := awsec2.Vpc_FromLookup(stack, jsii.String("DefaultVPC"), &awsec2.VpcLookupOptions{IsDefault: jsii.Bool(true)})

  // EC2 Construct
  awsec2.NewInstance(stack, jsii.String("Server"), &awsec2.InstanceProps{
    InstanceType: awsec2.NewInstanceType(jsii.String("t3.micro")),
    MachineImage: awsec2.NewAmazonLinuxImage(&awsec2.AmazonLinuxImageProps{
      Generation: awsec2.AmazonLinuxGeneration_AMAZON_LINUX_2,
    }),
    Vpc: vpc,
  })

  return stack
}
```

Then, to create the ElastiCache Construct, we use `NewCfnCacheCluster`:

```go
// Elasticache Construct
awselasticache.NewCfnCacheCluster(stack, jsii.String("Cache"), &awselasticache.CfnCacheClusterProps{
  Engine:        jsii.String("redis"),
  CacheNodeType: jsii.String("cache.t2.micro"),
  NumCacheNodes: jsii.Number(1),
})
```

We create ElastiCache with engine Redis and a single node.

Unlike the EC2 Construct *(an L2 Construct)*, the ElastiCache Construct is an *L1
Construct*. When we create it, there's no built-in Security Group to allow other
resources to access its port (I'll explain the **L Construct** concept in a later
post). So we need to create a Security Group for ElastiCache:

```go
// SG Construct
sg := awsec2.NewSecurityGroup(stack, jsii.String("CacheSG"), &awsec2.SecurityGroupProps{
  AllowAllOutbound: jsii.Bool(true),
  Vpc:              vpc,
})
sg.AddIngressRule(
  awsec2.Peer_AnyIpv4(),
  awsec2.NewPort(&awsec2.PortProps{
    FromPort:             jsii.Number(6379),
    ToPort:               jsii.Number(6379),
    StringRepresentation: jsii.String("Redis"),
    Protocol:             awsec2.Protocol_ALL,
  }),
  jsii.String("Redis Port"),
  jsii.Bool(false),
)

// Elasticache Construct
awselasticache.NewCfnCacheCluster(stack, jsii.String("Cache"), &awselasticache.CfnCacheClusterProps{
  Engine:              jsii.String("redis"),
  CacheNodeType:       jsii.String("cache.t2.micro"),
  NumCacheNodes:       jsii.Number(1),
  VpcSecurityGroupIds: &[]*string{sg.SecurityGroupId()},
})
```

We create a Security Group allowing access to port 6379 and attach it to
ElastiCache. Generate CloudFormation for `QuestionCacheStack`:

```bash
cdk synth QuestionCacheStack
```

**QuestionWorkerStack**

Finally, we work on `QuestionWorkerStack`.

![Worker stack]({{ '/assets/images/posts/aws-cdk-03-design-build-qa-infrastructure/worker-stack.png' | relative_url }})

`QuestionWorkerStack` includes three Constructs: VPC, EC2, and DynamoDB. Open
`worker-stack.go` and paste in the following:

```go
package stack

import (
  "github.com/aws/aws-cdk-go/awscdk/v2"
  "github.com/aws/aws-cdk-go/awscdk/v2/awsec2"
  "github.com/aws/constructs-go/constructs/v10"
  "github.com/aws/jsii-runtime-go"
)

type QuestionWorkerStackProps struct {
  awscdk.StackProps
}

func NewQuestionWorkerStack(scope constructs.Construct, id string, props *QuestionWorkerStackProps) awscdk.Stack {
  var sprops awscdk.StackProps
  if props != nil {
    sprops = props.StackProps
  }
  stack := awscdk.NewStack(scope, &id, &sprops)

  // VPC Construct
  vpc := awsec2.Vpc_FromLookup(stack, jsii.String("DefaultVPC"), &awsec2.VpcLookupOptions{IsDefault: jsii.Bool(true)})

  // EC2 Construct
  awsec2.NewInstance(stack, jsii.String("Worker"), &awsec2.InstanceProps{
    InstanceType: awsec2.NewInstanceType(jsii.String("t3.micro")),
    MachineImage: awsec2.NewAmazonLinuxImage(&awsec2.AmazonLinuxImageProps{
      Generation: awsec2.AmazonLinuxGeneration_AMAZON_LINUX_2,
    }),
    Vpc: vpc,
  })

  return stack
}
```

We use `awsdynamodb.NewTable` to create the DynamoDB table:

```go
// DynamoDB Construct
awsdynamodb.NewTable(stack, jsii.String("QuestionID"), &awsdynamodb.TableProps{
  TableName: jsii.String("QuestionID"),
  PartitionKey: &awsdynamodb.Attribute{
    Name: jsii.String("id"),
    Type: awsdynamodb.AttributeType_STRING,
  },
})
```

We create a DynamoDB table named `QuestionID` with one column, `id`. Generate
CloudFormation for `QuestionWorkerStack`:

```bash
cdk synth QuestionWorkerStack
```

## Deploy

To deploy an app with multiple Stacks, add the Stack name to the `deploy` command.
Deploy each Stack in order:

QuestionCacheStack:

```bash
cdk deploy QuestionCacheStack
```

QuestionWorkerStack:

```bash
cdk deploy QuestionWorkerStack
```

QuestionInsertStack:

```bash
cdk deploy QuestionInsertStack
```

Check the AWS Console and you'll see your resources. When you're done, remember to
delete the resources to avoid getting charged. Run `destroy` with each Stack name
in order:

```bash
cdk destroy QuestionCacheStack
cdk destroy QuestionWorkerStack
cdk destroy QuestionInsertStack
```

## Conclusion

We've now learned how to design and build infrastructure with CDK in this example.
As you can see, it's not that hard.
