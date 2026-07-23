package main

import (
	"testing"

	"github.com/aws/aws-cdk-go/awscdk/v2"
	"github.com/aws/aws-cdk-go/awscdk/v2/assertions"
	"github.com/aws/jsii-runtime-go"
)

// Fine-grained assertions: check that specific resources exist with the
// properties we expect.
func TestQuestionStack(t *testing.T) {
	defer jsii.Close()

	app := awscdk.NewApp(nil)
	stack := NewQuestionStack(app, "TestStack", nil)
	template := assertions.Template_FromStack(stack, nil)

	// Exactly one versioned S3 bucket.
	template.ResourceCountIs(jsii.String("AWS::S3::Bucket"), jsii.Number(1))
	template.HasResourceProperties(jsii.String("AWS::S3::Bucket"), map[string]interface{}{
		"VersioningConfiguration": map[string]interface{}{"Status": "Enabled"},
	})

	// A pay-per-request DynamoDB table keyed by "id".
	template.HasResourceProperties(jsii.String("AWS::DynamoDB::Table"), map[string]interface{}{
		"BillingMode": "PAY_PER_REQUEST",
	})
}

// Snapshot test: fail if the synthesized template changes unexpectedly.
// Run `go test -update` (with a snapshot helper) or use assertions to compare
// against a stored template. Here we simply assert the template is non-empty.
func TestSnapshot(t *testing.T) {
	defer jsii.Close()

	app := awscdk.NewApp(nil)
	stack := NewQuestionStack(app, "SnapshotStack", nil)
	template := assertions.Template_FromStack(stack, nil)

	if template.ToJSON() == nil {
		t.Fatal("expected a synthesized template")
	}
}
