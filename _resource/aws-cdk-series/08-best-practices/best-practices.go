package main

import (
	"github.com/aws/aws-cdk-go/awscdk/v2"
	"github.com/aws/aws-cdk-go/awscdk/v2/awsec2"
	"github.com/aws/aws-cdk-go/awscdk/v2/awsrds"
	"github.com/aws/aws-cdk-go/awscdk/v2/awss3"
	"github.com/aws/constructs-go/constructs/v10"
	"github.com/aws/jsii-runtime-go"
)

type BestPracticesStackProps struct {
	awscdk.StackProps
}

func NewBestPracticesStack(scope constructs.Construct, id string, props *BestPracticesStackProps) awscdk.Stack {
	var sprops awscdk.StackProps
	if props != nil {
		sprops = props.StackProps
	}
	stack := awscdk.NewStack(scope, &id, &sprops)

	vpc := awsec2.Vpc_FromLookup(stack, jsii.String("DefaultVPC"), &awsec2.VpcLookupOptions{
		IsDefault: jsii.Bool(true),
	})

	// 1. Tag everything in the stack in one place. Every resource that supports
	//    tags inherits these — great for cost allocation and ownership.
	awscdk.Tags_Of(stack).Add(jsii.String("Project"), jsii.String("question-service"), nil)
	awscdk.Tags_Of(stack).Add(jsii.String("ManagedBy"), jsii.String("cdk"), nil)

	// 2. Be explicit about removal policy. Keep data by default; only destroy
	//    it in throwaway environments.
	awss3.NewBucket(stack, jsii.String("Data"), &awss3.BucketProps{
		Versioned:     jsii.Bool(true),
		RemovalPolicy: awscdk.RemovalPolicy_RETAIN,
	})

	// 3. Never hardcode secrets. Let CDK generate one in Secrets Manager and
	//    hand the reference to RDS — the plaintext never touches your code.
	awsrds.NewDatabaseInstance(stack, jsii.String("Postgres"), &awsrds.DatabaseInstanceProps{
		Engine: awsrds.DatabaseInstanceEngine_Postgres(&awsrds.PostgresInstanceEngineProps{
			Version: awsrds.PostgresEngineVersion_VER_16(),
		}),
		InstanceType: awsec2.NewInstanceType(jsii.String("t3.micro")),
		Credentials:  awsrds.Credentials_FromGeneratedSecret(jsii.String("question"), nil),
		Vpc:          vpc,
	})

	return stack
}

func main() {
	defer jsii.Close()

	app := awscdk.NewApp(nil)
	NewBestPracticesStack(app, "BestPracticesStack", &BestPracticesStackProps{})
	app.Synth(nil)
}
