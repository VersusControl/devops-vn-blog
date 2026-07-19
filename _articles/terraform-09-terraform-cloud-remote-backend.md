---
layout: post
title: "Terraform Cloud as a Remote Backend"
series: "Terraform Series"
series_url: /terraform-series/
part: 9
date: 2022-12-29
author: Quan Huynh
subtitle: "Set up Terraform Cloud as a Remote Backend, store credentials centrally, and run plan/apply remotely."
tags: [terraform, iac, aws, backend]
image: /assets/images/posts/terraform-09-terraform-cloud-remote-backend/01.png
---

In the previous part we discussed the S3 Standard Backend. In this part we'll learn about the next kind of backend: the Remote Backend. We'll use Terraform Cloud as our Remote Backend.

## Using the Remote Backend

Read the [Terraform Backend](/terraform-07-what-is-terraform-backend/) part to better understand the pros and cons of the Remote Backend.

To use the Remote Backend, we need to create an account and log into Terraform Cloud.

### Terraform Cloud

Terraform Cloud is a HashiCorp service that helps us manage resources more easily and securely. It also makes building CI/CD for provisioning infrastructure very simple.

![Terraform Cloud](/assets/images/posts/terraform-09-terraform-cloud-remote-backend/02.png)

Terraform Cloud has three ways to use it:

- Version control workflow
- CLI-driven workflow
- API-driven workflow

We'll use the CLI-driven workflow for the Remote Backend, and the Version Control workflow for CI/CD.

### Creating an account

First, to work with Terraform Cloud we must create an account. Go to this link, [Signup](https://app.terraform.io/signup/account), and create an account.

![Signup](/assets/images/posts/terraform-09-terraform-cloud-remote-backend/03.png)

Then log into Terraform Cloud and choose **Start from scratch**.

![Start from scratch](/assets/images/posts/terraform-09-terraform-cloud-remote-backend/04.png)

In the next step we enter the Organization information. Then click create, and once created we'll see the UI below.

![Organization UI](/assets/images/posts/terraform-09-terraform-cloud-remote-backend/05.png)

So we're all set up; now we'll work with the Remote Backend.

### Usage

To use the Remote Backend, in the Workspaces UI we click to create a workspace and choose the CLI-driven workflow.

![CLI-driven workflow](/assets/images/posts/terraform-09-terraform-cloud-remote-backend/06.png)

Then we enter the workspace name and click create.

![Workspace name](/assets/images/posts/terraform-09-terraform-cloud-remote-backend/07.png)

After it's created, our workspace is ready to use.

![Workspace ready](/assets/images/posts/terraform-09-terraform-cloud-remote-backend/08.png)

We'll see the workspace status is *Waiting for configuration*; next we'll configure Terraform Local to connect to the Remote Backend.

Scrolling down we'll see the configuration and usage section.

![Configuration and usage](/assets/images/posts/terraform-09-terraform-cloud-remote-backend/09.png)

First we create a directory and a `main.tf` file with this code.

```
provider "aws" {
  region = "us-west-2"
}

data "aws_ami" "ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  owners = ["099720109477"]
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

To use the Remote Backend we need to add the following configuration to the Terraform file.

```
terraform {
  cloud {
    organization = <organization-name>

    workspaces {
      name = <workspace-name>
    }
  }
}
```

We use a `cloud` block with two attributes, `organization` and `workspaces`. Update the `main.tf` file with the configuration of the workspace we just created above.

> Use the cloud block with Terraform version 1.1 and above; for versions below 1.1 use the remote block.

```
terraform {
 cloud {
   organization = "HPI"

   workspaces {
     name = "terraform-series-remote-backend"
   }
 }
}

provider "aws" {
 region = "us-west-2"
}

...
```

Next we run `terraform login` to log into the Remote Backend. When we run it we'll see the UI below.

![Login UI](/assets/images/posts/terraform-09-terraform-cloud-remote-backend/10.png)

Click **Create API token**.

![Create API token](/assets/images/posts/terraform-09-terraform-cloud-remote-backend/11.png)

Copy the value and click **Done**, then go back to the terminal and paste the value we just copied.

![Paste the token](/assets/images/posts/terraform-09-terraform-cloud-remote-backend/12.png)

If the value is correct, our Terraform Local has successfully logged into Terraform Cloud.

![Login successful](/assets/images/posts/terraform-09-terraform-cloud-remote-backend/13.png)

After logging in, we run `init`.

```
terraform init
```

```clojure
Initializing Terraform Cloud...

Initializing provider plugins...
- Finding latest version of hashicorp/aws...
- Installing hashicorp/aws v4.8.0...
- Installed hashicorp/aws v4.8.0 (signed by HashiCorp)

Terraform has created a lock file .terraform.lock.hcl to record the provider
selections it made above. Include this file in your version control repository
so that Terraform can guarantee to make the same selections by default when
you run "terraform init" in the future.

Terraform Cloud has been successfully initialized!

You may now begin working with Terraform Cloud. Try running "terraform plan" to
see any changes that are required for your infrastructure.

If you ever set or change modules or Terraform Settings, run "terraform init"
again to reinitialize your working directory.
```

So we've successfully configured the Remote Backend. Now let's try running `terraform plan`.

```
terraform plan
```

```coffeescript
Running plan in Terraform Cloud. Output will stream here. Pressing Ctrl-C
will stop streaming the logs, but will not stop the plan running remotely.

Preparing the remote plan...

To view this run in a browser, visit:
https://app.terraform.io/app/HPI/terraform-series-remote-backend/runs/run-7R7giQVT4TqnaAzL

Waiting for the plan to start...

Terraform v1.1.7
on linux_amd64
Configuring remote state backend...
Initializing Terraform configuration...
╷
│ Error: error configuring Terraform AWS Provider: no valid credential sources for Terraform AWS Provider found.
```

You'll see it reports an error, because now that we're using the Remote Backend, all configuration related to credentials — such as the AWS `secret key` and `access key` — must be configured on the Remote Backend. This is a strength of the Remote Backend: all credential-related configuration is in one place, without needing to store credentials on our machine, which improves security.

To configure the credentials, click over to **Settings** and choose **Variable sets**.

![Settings — Variable sets](/assets/images/posts/terraform-09-terraform-cloud-remote-backend/14.png)

Click create, name the `variable set` "AWS Credentials", and choose **Apply to all workspaces in this organization**.

![Create variable set](/assets/images/posts/terraform-09-terraform-cloud-remote-backend/15.png)

Next we create variables to store the two values `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`. Click **Add variable** for `AWS_ACCESS_KEY_ID`, choose **Environment variable**, and fill in the value — **remember to mark that variable as Sensitive**.

![Add the access key](/assets/images/posts/terraform-09-terraform-cloud-remote-backend/16.png)

Do the same for `AWS_SECRET_ACCESS_KEY`.

![Add the secret key](/assets/images/posts/terraform-09-terraform-cloud-remote-backend/17.png)

Click save.

![Save](/assets/images/posts/terraform-09-terraform-cloud-remote-backend/18.png)

Now we run `terraform plan` again.

```
terraform plan
```

```coffeescript
Running plan in Terraform Cloud. Output will stream here. Pressing Ctrl-C
will stop streaming the logs, but will not stop the plan running remotely.

Preparing the remote plan...
...

Plan: 1 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + public_ip = (known after apply)
```

Let's run `apply`.

```
terraform apply
```

```coffeescript
...
aws_instance.server: Creating...
aws_instance.server: Still creating... [10s elapsed]
aws_instance.server: Creation complete after 12s [id=i-0839b6f71c5749de4]

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.

Outputs:

public_ip = "34.220.170.155"
```

When `apply` finishes, our state file is now stored on Terraform Cloud. On Terraform Cloud, click over to the **State** section.

![State](/assets/images/posts/terraform-09-terraform-cloud-remote-backend/19.png)

Click **Triggered via CLI** and we'll see the state file's value. In addition, Terraform Cloud shows us the current resources, helping us easily check them. Click over to the **Overview** tab and scroll down.

![Overview resources](/assets/images/posts/terraform-09-terraform-cloud-remote-backend/20.png)

**Important:** note that when we run Terraform commands with the Remote Backend, the Terraform runtime does not run on our machine but on the Remote Server, and it streams the result back to our machine. Therefore, if you press `Ctrl + C` to stop while it's running, it only stops the stream — Terraform on the Remote Server keeps running normally.

![Ctrl + C note](/assets/images/posts/terraform-09-terraform-cloud-remote-backend/21.png)

## Conclusion

So we've learned how to use the Terraform Remote Backend. Using it centralizes all credential configuration in one place, helps teams work more effectively, and ensures security. In the next part we'll learn about **CI/CD with Terraform Cloud**.
