package main

import (
	"github.com/aws/aws-cdk-go/awscdk/v2"
	"github.com/aws/aws-cdk-go/awscdk/v2/awsec2"
	"github.com/aws/aws-cdk-go/awscdk/v2/awselasticache"
	"github.com/aws/aws-cdk-go/awscdk/v2/awss3"
	"github.com/aws/constructs-go/constructs/v10"
	"github.com/aws/jsii-runtime-go"
)

type LayersStackProps struct {
	awscdk.StackProps
}

// One stack showing an L2 construct (S3) next to an L1 construct (ElastiCache).
func NewLayersStack(scope constructs.Construct, id string, props *LayersStackProps) awscdk.Stack {
	var sprops awscdk.StackProps
	if props != nil {
		sprops = props.StackProps
	}
	stack := awscdk.NewStack(scope, &id, &sprops)

	// L2 construct: a few simple props and CDK fills in the rest.
	awss3.NewBucket(stack, jsii.String("L2"), &awss3.BucketProps{
		Versioned: jsii.Bool(false),
	})

	// L1 construct (Cfn*): you must wire up everything yourself, including the
	// security group that opens the Redis port.
	vpc := awsec2.Vpc_FromLookup(stack, jsii.String("DefaultVPC"), &awsec2.VpcLookupOptions{
		IsDefault: jsii.Bool(true),
	})

	sg := awsec2.NewSecurityGroup(stack, jsii.String("CacheSG"), &awsec2.SecurityGroupProps{
		AllowAllOutbound: jsii.Bool(true),
		Vpc:              vpc,
	})
	sg.AddIngressRule(
		awsec2.Peer_AnyIpv4(),
		awsec2.Port_Tcp(jsii.Number(6379)),
		jsii.String("Redis Port"),
		jsii.Bool(false),
	)

	awselasticache.NewCfnCacheCluster(stack, jsii.String("Cache"), &awselasticache.CfnCacheClusterProps{
		Engine:              jsii.String("redis"),
		CacheNodeType:       jsii.String("cache.t3.micro"),
		NumCacheNodes:       jsii.Number(1),
		VpcSecurityGroupIds: &[]*string{sg.SecurityGroupId()},
	})

	return stack
}

func main() {
	defer jsii.Close()

	app := awscdk.NewApp(nil)
	NewLayersStack(app, "LayersStack", &LayersStackProps{})
	app.Synth(nil)
}
