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

	awsec2.NewInstance(stack, jsii.String("Server"), &awsec2.InstanceProps{
		InstanceType: awsec2.NewInstanceType(jsii.String("t3.micro")),
		MachineImage: awsec2.MachineImage_LatestAmazonLinux2023(),
		Vpc:          props.Vpc,
	})

	return stack
}
