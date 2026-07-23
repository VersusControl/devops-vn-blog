package main

import (
	"os"

	"github.com/aws/aws-cdk-go/awscdk/v2"
	"github.com/aws/aws-cdk-go/awscdk/v2/awsec2"
	"github.com/aws/aws-cdk-go/awscdk/v2/awsrds"
	"github.com/aws/constructs-go/constructs/v10"
	"github.com/aws/jsii-runtime-go"
)

type QuestionServiceStackProps struct {
	awscdk.StackProps
}

func NewQuestionServiceStack(scope constructs.Construct, id string, props *QuestionServiceStackProps) awscdk.Stack {
	var sprops awscdk.StackProps
	if props != nil {
		sprops = props.StackProps
	}
	stack := awscdk.NewStack(scope, &id, &sprops)

	// VPC Construct — reuse the default VPC.
	vpc := awsec2.Vpc_FromLookup(stack, jsii.String("DefaultVPC"), &awsec2.VpcLookupOptions{
		IsDefault: jsii.Bool(true),
	})

	// RDS Construct — a small PostgreSQL 16 database.
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

	// EC2 Construct — the API server.
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

	NewQuestionServiceStack(app, "QuestionServiceStack", &QuestionServiceStackProps{
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
