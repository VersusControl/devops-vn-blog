package main

import (
	"os"

	"question-service/stack"

	"github.com/aws/aws-cdk-go/awscdk/v2"
	"github.com/aws/jsii-runtime-go"
)

func main() {
	defer jsii.Close()

	app := awscdk.NewApp(nil)

	stack.NewQuestionCacheStack(app, "QuestionCacheStack", &stack.QuestionCacheStackProps{
		StackProps: awscdk.StackProps{Env: env()},
	})

	stack.NewQuestionWorkerStack(app, "QuestionWorkerStack", &stack.QuestionWorkerStackProps{
		StackProps: awscdk.StackProps{Env: env()},
	})

	stack.NewQuestionInsertStack(app, "QuestionInsertStack", &stack.QuestionInsertStackProps{
		StackProps: awscdk.StackProps{Env: env()},
	})

	app.Synth(nil)
}

func env() *awscdk.Environment {
	return &awscdk.Environment{
		Account: jsii.String(os.Getenv("CDK_DEFAULT_ACCOUNT")),
		Region:  jsii.String(os.Getenv("CDK_DEFAULT_REGION")),
	}
}
