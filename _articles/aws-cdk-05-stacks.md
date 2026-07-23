---
layout: post
title: "Stacks"
series: "AWS CDK"
series_url: /aws-cdk-series/
part: 5
date: 2023-03-31
author: Quan Huynh
tags: [aws, cdk, iac, go]
image: /assets/images/posts/aws-cdk-05-stacks/cover.svg
---

In this post we'll take a deeper look at Stacks and how to use resources from one
Stack in other Stacks.

## Stack

As we learned in previous posts, a Stack is a collection of related resources. Its
purpose is to make managing and structuring the source code easier.

An AWS CDK application can have one or more Stacks, for example:

```go
app := awscdk.NewApp(nil)

MyFirstStack(app, "stack1")
MySecondStack(app, "stack2")

app.Synth(nil)
```

To list all Stacks, use `cdk ls`:

```
stack1
stack2
```

When running `synth` to generate AWS CloudFormation for a multi-Stack app, pass in
the Stack name:

```bash
cdk synth stack1
```

With AWS CDK and Stacks, we can easily structure the resources needed for different
environments. For example, suppose we have an app and need to deploy infrastructure
for `dev` and `prod`. Our infrastructure has three Stacks: Application Stack,
Monitoring Stack, and CI/CD Stack.

In the `dev` environment, we usually don't need the Monitoring Stack, to save cost.
Building infrastructure for these two environments with that requirement is quite
easy in CDK. Here's an example: we create 3 functions for the 3 Stacks.

```go
package main

import (
  "github.com/aws/aws-cdk-go/awscdk/v2"
  "github.com/aws/constructs-go/constructs/v10"
)

func NewMonitoringStack(scope constructs.Construct, id string) {
  awscdk.NewStack(scope, &id, &awscdk.StackProps{})
}

func NewAppStack(scope constructs.Construct, id string) {
  awscdk.NewStack(scope, &id, &awscdk.StackProps{})
}

func NewCICDStack(scope constructs.Construct, id string) {
  awscdk.NewStack(scope, &id, &awscdk.StackProps{})
}

func main() {
  app := awscdk.NewApp(nil)

  app.Synth(nil)
}

func env() *awscdk.Environment {
  return nil
}
```

Next, we write another function to combine the 3 Stacks above and use an `if`
statement so the Monitoring Stack is only created for `prod`:

```go
func NewService(scope constructs.Construct, id string, props *ServiceProps) {
  stack := awscdk.NewStage(scope, &id, &awscdk.StageProps{
    Env: env(),
  })

  if props != nil && props.Prod {
    NewMonitoringStack(stack, "monitoring")
  }

  NewAppStack(stack, "app")
  NewCICDStack(stack, "cicd")
}
```

Update the `main()` function:

```go
package main

import (
  "github.com/aws/aws-cdk-go/awscdk/v2"
  "github.com/aws/constructs-go/constructs/v10"
)

func NewMonitoringStack(scope constructs.Construct, id string) {
  awscdk.NewStack(scope, &id, &awscdk.StackProps{})
}

func NewAppStack(scope constructs.Construct, id string) {
  awscdk.NewStack(scope, &id, &awscdk.StackProps{})
}

func NewCICDStack(scope constructs.Construct, id string) {
  awscdk.NewStack(scope, &id, &awscdk.StackProps{})
}

type ServiceProps struct {
  Prod bool `json:"prod"`
}

type Service struct {
  constructs.Construct
}

func NewService(scope constructs.Construct, id string, props *ServiceProps) {
  stack := awscdk.NewStage(scope, &id, &awscdk.StageProps{
    Env: env(),
  })

  if props != nil && props.Prod {
    NewMonitoringStack(stack, "monitoring")
  }

  NewAppStack(stack, "app")
  NewCICDStack(stack, "cicd")
}

func main() {
  app := awscdk.NewApp(nil)

  NewService(app, "dev", nil)
  NewService(app, "prod", &ServiceProps{Prod: true})

  app.Synth(nil)
}

func env() *awscdk.Environment {
  return nil
}
```

Run `ls` to see the Stacks created:

```bash
cdk ls
```

```
dev/app
dev/cicd
prod/app
prod/cicd
prod/monitoring
```

As you can see, building infrastructure for different environments with CDK is very
easy.

## Using Constructs Across Stacks

A tricky organizational problem that often occurs when using IaC tools is: defining
shared resources and using them across different infrastructures.

For example, consider this case: our project is built on AWS with a microservices
architecture, and we decide to use Terraform as the infrastructure tool. We create
one codebase for each service and write code to create the infrastructure. Usually
we create an AWS VPC first, then create other resources inside that VPC —
everything is fine.

Next, our project expands and needs another service. We create another codebase and
write code, but we realize this new service needs to be inside the same VPC as the
previous service. Now a problem appears: how do we use the VPC we created earlier?

With Terraform we do this:

```hcl
data "aws_vpc" "vpc" {
  id = var.vpc_id // The ID of the VPC we created
}
```

There's nothing wrong with this, but it makes our project harder in terms of source
code organization and resource management. One codebase's resources are hardcoded
with values from another codebase. **I won't cover how to solve this problem with
Terraform in this post.**

With CDK we can solve this quite simply by passing Constructs between Stacks. To
understand it better, let's build infrastructure for a microservices system with
two services: User and Post.

## Applying It

Create the directory and initialize the app:

```bash
mkdir referencing && cd referencing
```

```bash
cdk init --language go && go get
```

Create a `stack` directory with 3 files:

```
└── stack
    ├── global.go
    ├── post-service-stack.go
    └── user-service-stack.go
```

We put all the shared resources in `global.go`:

```go
package stack

import (
  "github.com/aws/aws-cdk-go/awscdk/v2"
  "github.com/aws/aws-cdk-go/awscdk/v2/awsec2"
  "github.com/aws/constructs-go/constructs/v10"
  "github.com/aws/jsii-runtime-go"
)

type GlobalStackProps struct {
  awscdk.StackProps
}

type GlobalStackResource struct {
  Vpc awsec2.IVpc
}

func NewGlobalStack(scope constructs.Construct, id string, props *GlobalStackProps) *GlobalStackResource {
  var sprops awscdk.StackProps
  if props != nil {
    sprops = props.StackProps
  }
  stack := awscdk.NewStack(scope, &id, &sprops)

  vpc := awsec2.NewVpc(stack, jsii.String("VPC"), &awsec2.VpcProps{})

  return &GlobalStackResource{
    Vpc: vpc,
  }
}
```

In the other two files we write code for the User Service and Post Service.
`user-service-stack.go`:

```go
package stack

import (
  "github.com/aws/aws-cdk-go/awscdk/v2"
  "github.com/aws/aws-cdk-go/awscdk/v2/awsec2"
  "github.com/aws/constructs-go/constructs/v10"
  "github.com/aws/jsii-runtime-go"
)

type UserServiceStackProps struct {
  StackProps awscdk.StackProps
  Vpc        awsec2.IVpc
}

func NewUserServiceStack(scope constructs.Construct, id string, props *UserServiceStackProps) awscdk.Stack {
  var sprops awscdk.StackProps
  if props != nil {
    sprops = props.StackProps
  }
  stack := awscdk.NewStack(scope, &id, &sprops)

  // EC2 Construct
  awsec2.NewInstance(stack, jsii.String("Server"), &awsec2.InstanceProps{
    InstanceType: awsec2.NewInstanceType(jsii.String("t3.micro")),
    MachineImage: awsec2.MachineImage_LatestAmazonLinux2023(),
    Vpc:          props.Vpc,
  })

  return stack
}
```

`post-service-stack.go`:

```go
package stack

import (
  "github.com/aws/aws-cdk-go/awscdk/v2"
  "github.com/aws/aws-cdk-go/awscdk/v2/awsec2"
  "github.com/aws/constructs-go/constructs/v10"
  "github.com/aws/jsii-runtime-go"
)

type PostServiceStackProps struct {
  StackProps awscdk.StackProps
  Vpc        awsec2.IVpc
}

func NewPostServiceStack(scope constructs.Construct, id string, props *PostServiceStackProps) awscdk.Stack {
  var sprops awscdk.StackProps
  if props != nil {
    sprops = props.StackProps
  }
  stack := awscdk.NewStack(scope, &id, &sprops)

  // EC2 Construct
  awsec2.NewInstance(stack, jsii.String("Server"), &awsec2.InstanceProps{
    InstanceType: awsec2.NewInstanceType(jsii.String("t3.micro")),
    MachineImage: awsec2.MachineImage_LatestAmazonLinux2023(),
    Vpc:          props.Vpc,
  })

  return stack
}
```

In `referencing.go` we create the Global Stack and pass the related resources to
the other Stacks.

```go
package main

import (
  "referencing/stack"

  "github.com/aws/aws-cdk-go/awscdk/v2"
  "github.com/aws/jsii-runtime-go"
)

func main() {
  defer jsii.Close()

  // App
  app := awscdk.NewApp(nil)

  // Global Resource
  resource := stack.NewGlobalStack(app, "GlobalStack", &stack.GlobalStackProps{
    StackProps: awscdk.StackProps{
      Env: env(),
    },
  })

  // User Service Stack
  stack.NewUserServiceStack(app, "UserServiceStack", &stack.UserServiceStackProps{
    StackProps: awscdk.StackProps{
      Env: env(),
    },
    Vpc: resource.Vpc,
  })

  // Post Service Stack
  stack.NewPostServiceStack(app, "PostServiceStack", &stack.PostServiceStackProps{
    StackProps: awscdk.StackProps{
      Env: env(),
    },
    Vpc: resource.Vpc,
  })

  app.Synth(nil)
}

func env() *awscdk.Environment {
  return nil
}
```

Run `cdk ls` to list the Stacks:

```
GlobalStack
PostServiceStack
UserServiceStack
```

Next, run `deploy` to create the resources. **Note** that because
`UserServiceStack` and `PostServiceStack` both depend on `GlobalStack`'s resources,
we need to create `GlobalStack` first.

We can run `cdk --all` to have CDK automatically create the infrastructure in order,
but in a real environment we should specify each Stack explicitly when deploying, to
be safe.

```bash
cdk deploy GlobalStack
cdk deploy PostServiceStack
cdk deploy UserServiceStack
```

Remember to delete the resources when you're done to avoid getting charged.

## Conclusion

We've now taken a closer look at how to use Stacks in CDK. With CDK, organizing
source code is much simpler than with other IaC tools.

At this point you can build real infrastructure with CDK. But there's a big
difference between code that *works* and code you'd trust in production. Because CDK
is real code, we can do things no YAML template can: write unit tests, run it in a
CI/CD pipeline, and apply software engineering practices to our infrastructure. In
the [next post]({{ '/aws-cdk-series/' | relative_url }}) we'll start by learning how
to **test** CDK code.
