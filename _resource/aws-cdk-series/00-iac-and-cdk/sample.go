package main

import (
	"os"

	"github.com/aws/aws-cdk-go/awscdk/v2"
	"github.com/aws/aws-cdk-go/awscdk/v2/awsec2"
	"github.com/aws/constructs-go/constructs/v10"
	"github.com/aws/jsii-runtime-go"
)

type FirstAppStackProps struct {
	awscdk.StackProps
}

func NewFirstAppStack(scope constructs.Construct, id string, props *FirstAppStackProps) awscdk.Stack {
	var sprops awscdk.StackProps
	if props != nil {
		sprops = props.StackProps
	}
	stack := awscdk.NewStack(scope, &id, &sprops)

	// Look up the account's default VPC instead of creating one.
	vpc := awsec2.Vpc_FromLookup(stack, jsii.String("VPC"), &awsec2.VpcLookupOptions{
		IsDefault: jsii.Bool(true),
	})

	// A single EC2 instance running the latest Amazon Linux 2023 AMI.
	awsec2.NewInstance(stack, jsii.String("Server"), &awsec2.InstanceProps{
		InstanceType: awsec2.NewInstanceType(jsii.String("t3.micro")),
		MachineImage: awsec2.MachineImage_LatestAmazonLinux2023(),
		Vpc:          vpc,
	})

	return stack
}

func main() {
	defer jsii.Close()

	app := awscdk.NewApp(nil)

	NewFirstAppStack(app, "FirstAppStack", &FirstAppStackProps{
		awscdk.StackProps{
			Env: env(),
		},
	})

	app.Synth(nil)
}

func env() *awscdk.Environment {
	return &awscdk.Environment{
		Account: jsii.String(os.Getenv("CDK_DEFAULT_ACCOUNT")),
		Region:  jsii.String(os.Getenv("CDK_DEFAULT_REGION")),
	}
}
