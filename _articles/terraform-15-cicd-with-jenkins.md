---
layout: post
title: "Building CI/CD with Jenkins"
series: "Terraform Series"
series_url: /terraform-series/
part: 15
date: 2023-04-01
author: Quan Huynh
subtitle: "Set up a Jenkins pipeline for Terraform with credentials, the Terraform plugin, an S3 backend, and manual approval."
tags: [terraform, iac, aws, cicd, jenkins]
image: /assets/images/posts/terraform-15-cicd-with-jenkins/01.png
---

In the previous part we discussed how to use Terraform with GitLab CI. In this part we'll learn how to build CI/CD for Terraform with Jenkins.

Jenkins is a very popular CI/CD tool used by many people.

## Preparation

Before we write the Terraform code and the CI/CD file, we need to prepare the following so Terraform can run in Jenkins.

### GitHub

In this part I only show how to use Jenkins with Terraform. For more detail, you can read this: [How To Set Up Continuous Integration With Git and Jenkins?](https://www.lambdatest.com/blog/how-to-setup-continuous-integration-with-git-jenkins).

We create a GitHub repository (*Public*) to hold the source code and connect it to Jenkins. The source code used in this part: [Terraform Jenkins Example](https://github.com/hoalongnatsu/terraform-series-jenkins-example). Next, create a *Project* on Jenkins named `terraform-jenkins`, choosing the Pipeline type.

![Creating the pipeline project](/assets/images/posts/terraform-15-cicd-with-jenkins/02.png)

Click over to the Pipeline section and fill it in as below:

![Pipeline configuration](/assets/images/posts/terraform-15-cicd-with-jenkins/03.png)

Click save.

### AWS Credentials

Since we're using Terraform with AWS, we need to configure AWS credentials in Jenkins for Terraform. Follow this guide to create an IAM user with AdministratorAccess: [Creating your first IAM admin user and user group](https://docs.aws.amazon.com/IAM/latest/UserGuide/getting-started_create-admin-group.html).

Then create a Secret Key for the IAM user above. In Jenkins, choose **Manage Jenkins -> Manage Credentials**.

![Manage Credentials](/assets/images/posts/terraform-15-cicd-with-jenkins/04.png)

In the **Stores scoped to Jenkins** section, choose Jenkins.

![Stores scoped to Jenkins](/assets/images/posts/terraform-15-cicd-with-jenkins/05.png)

Choose **Global credentials**.

![Global credentials](/assets/images/posts/terraform-15-cicd-with-jenkins/06.png)

Choose **Add Credentials**.

![Add Credentials](/assets/images/posts/terraform-15-cicd-with-jenkins/07.png)

1. For the Kind field, choose Secret Text
2. Leave the Scope field as default
3. In the Secret field, enter the value of `AWS_ACCESS_KEY_ID`
4. The ID field is the secret's name; name it `aws-secret-key-id`
5. The Description field can be anything

Similarly, create another **Secret text** to hold the value of `AWS_SECRET_ACCESS_KEY` and name it `aws-secret-access-key`.

![Adding the secret access key](/assets/images/posts/terraform-15-cicd-with-jenkins/08.png)

### S3 Backend

Next we'll create an S3 backend to store the Terraform State; see more about the S3 backend here: [Using the S3 Standard Backend in a Project](/terraform-08-s3-standard-backend/). Download this repo: [Terraform Series](https://github.com/hoalongnatsu/terraform-series), move to `bai-14/s3-backend`, and run the following commands:

```
terraform init
terraform apply -auto-approve
```

When Terraform finishes, the S3 backend values are displayed.

```
Apply complete! Resources: 8 added, 0 changed, 0 destroyed.

Outputs:

config = {
  "bucket" = "terraform-series-s3-backend"
  "region" = "us-west-2"
  "role_arn" = "arn:aws:iam::112337013333:role/Terraform-SeriesS3BackendRole"
}
```

Copy these values down.

### Combining with Terraform

To run Terraform in Jenkins we have the following options:

1. Install Terraform on the Build Agent
2. Use a Docker container
3. Use the Terraform plugin

We'll use the third option in this part. Go to **Manage Jenkins -> Manage Plugins**, find the Terraform plugin, and click Install.

![Installing the Terraform plugin](/assets/images/posts/terraform-15-cicd-with-jenkins/09.png)

Then go to **Manage Jenkins -> Global Tool Configuration**, find the Terraform section, and configure it as follows:

![Global Tool Configuration](/assets/images/posts/terraform-15-cicd-with-jenkins/10.png)

Next we build the CI/CD flow.

## CI/CD

Create a file named `main.tf`.

```hcl
terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket       = "terraform-series-s3-backend"
    key          = "terraform-jenkins"
    region       = "us-west-2"
    encrypt      = true
    role_arn     = "arn:aws:iam::<ACCOUNT_ID>:role/Terraform-SeriesS3BackendRole"
    use_lockfile = true
  }
}

provider "aws" {
  region = "us-west-2"
}

data "aws_ami" "ami" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

resource "aws_instance" "server" {
  ami           = data.aws_ami.ami.id
  instance_type = "t3.micro"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "Server"
  }
}

output "public_ip" {
  value = aws_instance.server.public_ip
}
```

Configure the S3 backend as follows (using `use_lockfile` for S3-native locking instead of a DynamoDB table):

```hcl
terraform {
  backend "s3" {
    bucket       = "terraform-series-s3-backend"
    key          = "terraform-jenkins"
    region       = "us-west-2"
    encrypt      = true
    role_arn     = "arn:aws:iam::<ACCOUNT_ID>:role/Terraform-SeriesS3BackendRole"
    use_lockfile = true
  }
}
```

**Change `<ACCOUNT_ID>` to your ID.** Next we create a `Jenkinsfile`:

```
pipeline {
  agent any

  tools {
    terraform 'terraform'
  }

  environment {
    AWS_ACCESS_KEY_ID     = credentials('aws-secret-key-id')
    AWS_SECRET_ACCESS_KEY = credentials('aws-secret-access-key')
  }

  stages {
    stage('Init Provider') {
      steps {
        sh 'terraform init'
      }
    }
    stage('Plan Resources') {
      steps {
        sh 'terraform plan -out planfile'
      }
    }
    stage('Apply Resources') {
      input {
        message "Do you want to proceed for production deployment?"
      }
      steps {
        sh 'terraform apply -input=false planfile'
      }
    }
  }
}
```

To use Terraform in the pipeline we use the attribute:

```
tools {
  terraform 'terraform'
}
```

This is the Global Tool we configured above when installing the Terraform plugin. And to use the AWS credentials we use these two attributes:

```
environment {
  AWS_ACCESS_KEY_ID     = credentials('aws-secret-key-id')
  AWS_SECRET_ACCESS_KEY = credentials('aws-secret-access-key')
}
```

The `credentials` function is used to get the value of the **Secret Text** we created. The remaining code runs Terraform, consisting of the `init`, `plan`, and `deploy` steps.

The `deploy` code is a bit different — it has an extra `input` attribute:

```
input {
  message "Do you want to proceed for production deployment?"
}
```

We use this attribute to implement a Manual Approve feature. We don't let CI/CD automatically run `terraform apply` — we want to preview which resources will be created first. We push the code to GitHub and go to Jenkins to execute CI/CD. This is Jenkins's old pipeline UI.

![Old pipeline UI](/assets/images/posts/terraform-15-cicd-with-jenkins/11.png)

Click **Open Blue Ocean** to switch to the new UI because it's nicer; you can use the old UI if you're not used to it yet.

![Blue Ocean](/assets/images/posts/terraform-15-cicd-with-jenkins/12.png)

Click Run to execute the job.

![Running the job](/assets/images/posts/terraform-15-cicd-with-jenkins/13.png)

Click the job to view the *logs*.

![Job logs](/assets/images/posts/terraform-15-cicd-with-jenkins/14.png)

The `Apply Resources` stage is in a waiting state; after reviewing the `plan` and confirming it's fine, we click **Proceed**. Check the AWS Console and you'll see the EC2 was successfully created by CI/CD.

## Conclusion

So we've learned how to use Terraform with Jenkins. In my opinion, which CI/CD tool you choose depends on your company and whether you're familiar with it. Don't rely on the rambling analysis articles online — they meander and never reach a clear conclusion.
