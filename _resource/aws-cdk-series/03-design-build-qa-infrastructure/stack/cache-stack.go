package stack

import (
	"github.com/aws/aws-cdk-go/awscdk/v2"
	"github.com/aws/aws-cdk-go/awscdk/v2/awsec2"
	"github.com/aws/aws-cdk-go/awscdk/v2/awselasticache"
	"github.com/aws/constructs-go/constructs/v10"
	"github.com/aws/jsii-runtime-go"
)

type QuestionCacheStackProps struct {
	awscdk.StackProps
}

// NewQuestionCacheStack: the read path — an API server in front of a Redis cache.
func NewQuestionCacheStack(scope constructs.Construct, id string, props *QuestionCacheStackProps) awscdk.Stack {
	var sprops awscdk.StackProps
	if props != nil {
		sprops = props.StackProps
	}
	stack := awscdk.NewStack(scope, &id, &sprops)

	vpc := awsec2.Vpc_FromLookup(stack, jsii.String("DefaultVPC"), &awsec2.VpcLookupOptions{
		IsDefault: jsii.Bool(true),
	})

	awsec2.NewInstance(stack, jsii.String("Server"), &awsec2.InstanceProps{
		InstanceType: awsec2.NewInstanceType(jsii.String("t3.micro")),
		MachineImage: awsec2.MachineImage_LatestAmazonLinux2023(),
		Vpc:          vpc,
	})

	// ElastiCache is an L1 construct, so it has no built-in security group —
	// we create one to open the Redis port (6379).
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
