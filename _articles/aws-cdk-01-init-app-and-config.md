---
layout: post
title: "Initializing the App and Writing Project Configuration"
series: "AWS CDK"
series_url: /aws-cdk-series/
part: 1
date: 2023-03-08
author: Quan Huynh
tags: [aws, cdk, iac, go]
image: /assets/images/posts/aws-cdk-01-init-app-and-config/cover.png
---

In the previous post, we learned about AWS CDK and built a simple example. In this
post, we'll look in more detail at the steps to initialize an app with CDK.

To provision new infrastructure using AWS CDK, we follow these steps:

1. Bootstrapping
2. Initialize the app with CDK
3. Write code
4. Generate AWS CloudFormation
5. Deploy the infrastructure

In addition, while working with CDK, there are two more steps:

1. Change configuration
2. Destroy infrastructure

To help you understand the steps above, we'll walk through an example that creates
an S3 bucket.

## Bootstrapping

This is a required step if you're using CDK for the first time to provision
infrastructure for an account in an AWS region where you haven't used CDK before.

The bootstrapping process creates the resources CDK needs to provision
infrastructure on AWS. Some of the resources it creates:

- An Amazon S3 bucket to store YAML files during provisioning
- The IAM roles CDK needs to create infrastructure on AWS

All of the necessary resources are defined inside a CloudFormation stack named
*CDKToolkit*. Because CloudFormation stacks exist per region, when provisioning in
a new region you must bootstrap that region before running CDK.

In this post we'll create an S3 bucket in `us-west-2`, where `ACCOUNT-NUMBER` is
your account ID.

```bash
cdk bootstrap aws://ACCOUNT-NUMBER/us-west-2
```

```
 ⏳  Bootstrapping environment aws://ACCOUNT-NUMBER/us-west-2
...
```

Wait for bootstrapping to finish, then open the
[CloudFormation Console](https://console.aws.amazon.com/cloudformation/home) and
you'll see the *CDKToolkit* stack.

## Initialize the App with CDK

Next we use CDK to initialize an app in the language we want.

```bash
mkdir s3-simple && cd s3-simple
```

```bash
cdk init app --language go
```

The directory structure after running `cdk init`:

```
.
├── README.md
├── cdk.json
├── go.mod
├── s3-simple.go
└── s3-simple_test.go
```

- `cdk.json` tells the CDK command how to run the CDK code
- `go.mod` contains the libraries CDK needs
- `s3-simple.go` is the file where we write our code

After initializing the app, run this command to download the CDK libraries:

```bash
go get
```

## Write Code

The default code of `s3-simple.go`:

```go
package main

import (
    "github.com/aws/aws-cdk-go/awscdk/v2"
    // "github.com/aws/aws-cdk-go/awscdk/v2/awssqs"
    "github.com/aws/constructs-go/constructs/v10"
    "github.com/aws/jsii-runtime-go"
)

type S3SimpleStackProps struct {
    awscdk.StackProps
}

func NewS3SimpleStack(scope constructs.Construct, id string, props *S3SimpleStackProps) awscdk.Stack {
    var sprops awscdk.StackProps
    if props != nil {
        sprops = props.StackProps
    }
    stack := awscdk.NewStack(scope, &id, &sprops)

    // The code that defines your stack goes here

    // example resource
    // queue := awssqs.NewQueue(stack, jsii.String("S3SimpleQueue"), &awssqs.QueueProps{
    //  VisibilityTimeout: awscdk.Duration_Seconds(jsii.Number(300)),
    // })

    return stack
}

func main() {
    defer jsii.Close()

    app := awscdk.NewApp(nil)

    NewS3SimpleStack(app, "S3SimpleStack", &S3SimpleStackProps{
        awscdk.StackProps{
            Env: env(),
        },
    })

    app.Synth(nil)
}

func env() *awscdk.Environment {
    return nil
}
```

There are three functions:

- `main()`
- `NewS3SimpleStack()`
- `env()`

I'll explain the code structure in later posts; for now we only care about the
`env()` function.

The `env()` function specifies the account and AWS region CDK uses for
provisioning. There are three options.

- Use the default account

```go
return nil
```

- Specify an exact account

```go
return &awscdk.Environment{
  Account: jsii.String("123456789012"),
  Region:  jsii.String("us-east-1"),
}
```

- Use the account configured by the CLI

```go
return &awscdk.Environment{
   Account: jsii.String(os.Getenv("CDK_DEFAULT_ACCOUNT")),
   Region:  jsii.String(os.Getenv("CDK_DEFAULT_REGION")),
}
```

The `NewS3SimpleStack()` function is used to specify the resources to create, as
you can see in the commented-out code inside the function:

```go
// queue := awssqs.NewQueue(stack, jsii.String("S3SimpleQueue"), &awssqs.QueueProps{
//   VisibilityTimeout: awscdk.Duration_Seconds(jsii.Number(300)),
// })
```

This is the code used to create an SQS (Simple Queue Service). Next, we'll update
`s3-simple.go` and add code to create an S3 bucket.

```go
package main

import (
    "github.com/aws/aws-cdk-go/awscdk/v2"
    "github.com/aws/aws-cdk-go/awscdk/v2/awss3"

    "github.com/aws/constructs-go/constructs/v10"
    "github.com/aws/jsii-runtime-go"
)

type S3SimpleStackProps struct {
    awscdk.StackProps
}

func NewS3SimpleStack(scope constructs.Construct, id string, props *S3SimpleStackProps) awscdk.Stack {
    var sprops awscdk.StackProps
    if props != nil {
        sprops = props.StackProps
    }
    stack := awscdk.NewStack(scope, &id, &sprops)

    awss3.NewBucket(stack, jsii.String("S3SimpleStack"), &awss3.BucketProps{
        Versioned: jsii.Bool(false),
    })

    return stack
}

func main() {
    defer jsii.Close()

    app := awscdk.NewApp(nil)

    NewS3SimpleStack(app, "S3SimpleStack", &S3SimpleStackProps{
        awscdk.StackProps{
            Env: env(),
        },
    })

    app.Synth(nil)
}

func env() *awscdk.Environment {
    return nil
}
```

## Generate AWS CloudFormation

After writing the code, run the following command to convert the CDK code into
CloudFormation — this is also how we preview the resources that will be created.

```bash
cdk synth
```

Output of the `synth` command:

```yaml
Resources:
  S3SimpleStack1351D274:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: s3-simple-stack
    UpdateReplacePolicy: Retain
    DeletionPolicy: Retain
    Metadata:
      aws:cdk:path: S3SimpleStack/S3SimpleStack/Resource
  ...
```

This result is stored in the `cdk.out` directory. When we run `deploy`, CDK reads
from `cdk.out` to provision the infrastructure.

## Deploy the Infrastructure

Finally, run `deploy`:

```bash
cdk deploy
```

The progress of the `deploy` command is shown in the terminal.

```
S3SimpleStack: deploying... [1/1]
[100%] success: Published ...
S3SimpleStack: creating CloudFormation changeset...

2:29:12 PM | CREATE_IN_PROGRESS   | AWS::CloudFormation::Stack | S3SimpleStack
2:29:18 PM | CREATE_IN_PROGRESS   | AWS::S3::Bucket    | S3SimpleStack
```

After CDK finishes, open the
[CloudFormation Console](https://console.aws.amazon.com/cloudformation/home) and
you'll see a stack named *S3SimpleStack*. CDK's main job is to generate the
CloudFormation configuration and use it to create the CloudFormation stack. The
rest of the provisioning is handled by CloudFormation.

## Change Configuration

During deployment we'll certainly change the infrastructure often. CDK lets us
edit the code and deploy the changed configuration onto the existing
infrastructure.

For example, change the S3 `Versioned` property to `true`:

```go
awss3.NewBucket(stack, jsii.String("S3SimpleStack"), &awss3.BucketProps{
  BucketName: jsii.String("s3-simple-stack"),
  Versioned:  jsii.Bool(true), // change here
})
```

CDK provides the `diff` command to compare the difference between the current code
and the deployed configuration.

```bash
cdk diff
```

```
Resources
[~] AWS::S3::Bucket S3SimpleStack S3SimpleStack1351D274
 └─ [+] VersioningConfiguration
     └─ {"Status":"Enabled"}
```

Next, run `deploy` and CDK will apply the change to the existing infrastructure.

```bash
cdk deploy
```

## Destroy Infrastructure

If we want to delete the current infrastructure to save money, use the `destroy`
command:

```bash
$ cdk destroy
Are you sure you want to delete: S3SimpleStack (y/n)?
```

Choose `y`.

```
S3SimpleStack: destroying... [1/1]

 ✅  S3SimpleStack: destroyed
```

At this point the AWS resources have been deleted successfully.

## Conclusion

We've now learned how to initialize an app and the steps needed to provision
infrastructure on AWS with CDK. As you can see, the CDK steps are quite similar to
Terraform and fairly easy to use.
