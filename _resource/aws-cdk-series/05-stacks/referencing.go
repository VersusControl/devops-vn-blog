package main

import (
	"referencing/stack"

	"github.com/aws/aws-cdk-go/awscdk/v2"
	"github.com/aws/jsii-runtime-go"
)

func main() {
	defer jsii.Close()

	app := awscdk.NewApp(nil)

	// Create the shared VPC once, then pass the construct into the other stacks.
	resource := stack.NewGlobalStack(app, "GlobalStack", &stack.GlobalStackProps{
		StackProps: awscdk.StackProps{Env: env()},
	})

	stack.NewUserServiceStack(app, "UserServiceStack", &stack.UserServiceStackProps{
		StackProps: awscdk.StackProps{Env: env()},
		Vpc:        resource.Vpc,
	})

	stack.NewPostServiceStack(app, "PostServiceStack", &stack.PostServiceStackProps{
		StackProps: awscdk.StackProps{Env: env()},
		Vpc:        resource.Vpc,
	})

	app.Synth(nil)
}

func env() *awscdk.Environment {
	return nil
}
