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

// GlobalStackResource exposes shared constructs (the VPC) to other stacks.
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

	return &GlobalStackResource{Vpc: vpc}
}
