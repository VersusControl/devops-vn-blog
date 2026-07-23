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

// NewQuestionInsertStack: the write path — an API server that inserts into RDS.
func NewQuestionInsertStack(scope constructs.Construct, id string, props *QuestionInsertStackProps) awscdk.Stack {
	var sprops awscdk.StackProps
	if props != nil {
		sprops = props.StackProps
	}
	stack := awscdk.NewStack(scope, &id, &sprops)

	vpc := awsec2.Vpc_FromLookup(stack, jsii.String("DefaultVPC"), &awsec2.VpcLookupOptions{
		IsDefault: jsii.Bool(true),
	})

	awsrds.NewDatabaseInstance(stack, jsii.String("Postgres"), &awsrds.DatabaseInstanceProps{
		Engine: awsrds.DatabaseInstanceEngine_Postgres(&awsrds.PostgresInstanceEngineProps{
			Version: awsrds.PostgresEngineVersion_VER_16(),
		}),
		InstanceType: awsec2.NewInstanceType(jsii.String("t3.micro")),
		Credentials: awsrds.Credentials_FromPassword(
			jsii.String("question"),
			awscdk.SecretValue_UnsafePlainText(jsii.String("question")),
		),
		PubliclyAccessible: jsii.Bool(true),
		VpcSubnets:         &awsec2.SubnetSelection{SubnetType: awsec2.SubnetType_PUBLIC},
		Vpc:                vpc,
	})

	awsec2.NewInstance(stack, jsii.String("Server"), &awsec2.InstanceProps{
		InstanceType: awsec2.NewInstanceType(jsii.String("t3.micro")),
		MachineImage: awsec2.MachineImage_LatestAmazonLinux2023(),
		Vpc:          vpc,
	})

	return stack
}
