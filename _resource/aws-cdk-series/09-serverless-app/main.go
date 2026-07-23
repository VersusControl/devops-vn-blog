package main

import (
	"github.com/aws/aws-cdk-go/awscdk/v2"
	"github.com/aws/aws-cdk-go/awscdk/v2/awsapigateway"
	"github.com/aws/aws-cdk-go/awscdk/v2/awsdynamodb"
	"github.com/aws/aws-cdk-go/awscdk/v2/awslambda"
	"github.com/aws/constructs-go/constructs/v10"
	"github.com/aws/jsii-runtime-go"
)

type ServerlessStackProps struct {
	awscdk.StackProps
}

// A fully serverless question service: API Gateway -> Lambda -> DynamoDB.
func NewServerlessStack(scope constructs.Construct, id string, props *ServerlessStackProps) awscdk.Stack {
	var sprops awscdk.StackProps
	if props != nil {
		sprops = props.StackProps
	}
	stack := awscdk.NewStack(scope, &id, &sprops)

	// The data store.
	table := awsdynamodb.NewTable(stack, jsii.String("Questions"), &awsdynamodb.TableProps{
		PartitionKey: &awsdynamodb.Attribute{
			Name: jsii.String("id"),
			Type: awsdynamodb.AttributeType_STRING,
		},
		BillingMode:   awsdynamodb.BillingMode_PAY_PER_REQUEST,
		RemovalPolicy: awscdk.RemovalPolicy_DESTROY,
	})

	// The Go handler. Build a `bootstrap` binary into the ./lambda folder first:
	//   GOOS=linux GOARCH=arm64 go build -tags lambda.norpc -o lambda/bootstrap ./lambda
	fn := awslambda.NewFunction(stack, jsii.String("Handler"), &awslambda.FunctionProps{
		Runtime:      awslambda.Runtime_PROVIDED_AL2023(),
		Architecture: awslambda.Architecture_ARM_64(),
		Handler:      jsii.String("bootstrap"),
		Code:         awslambda.Code_FromAsset(jsii.String("lambda"), nil),
		Environment: &map[string]*string{
			"TABLE_NAME": table.TableName(),
		},
	})

	// Give the function least-privilege access to just this table.
	table.GrantReadWriteData(fn)

	// Expose it over HTTP.
	awsapigateway.NewLambdaRestApi(stack, jsii.String("Api"), &awsapigateway.LambdaRestApiProps{
		Handler: fn,
	})

	return stack
}

func main() {
	defer jsii.Close()

	app := awscdk.NewApp(nil)
	NewServerlessStack(app, "ServerlessStack", &ServerlessStackProps{})
	app.Synth(nil)
}
