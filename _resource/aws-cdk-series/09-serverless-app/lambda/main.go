package main

import (
	"context"
	"encoding/json"
	"os"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/feature/dynamodb/attributevalue"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/google/uuid"
)

type Question struct {
	ID    string `json:"id" dynamodbav:"id"`
	Title string `json:"title" dynamodbav:"title"`
}

var (
	client *dynamodb.Client
	table  = os.Getenv("TABLE_NAME")
)

func handler(ctx context.Context, req events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	var q Question
	if err := json.Unmarshal([]byte(req.Body), &q); err != nil {
		return events.APIGatewayProxyResponse{StatusCode: 400, Body: "invalid body"}, nil
	}
	q.ID = uuid.NewString()

	item, err := attributevalue.MarshalMap(q)
	if err != nil {
		return events.APIGatewayProxyResponse{StatusCode: 500}, err
	}

	_, err = client.PutItem(ctx, &dynamodb.PutItemInput{
		TableName: aws.String(table),
		Item:      item,
	})
	if err != nil {
		return events.APIGatewayProxyResponse{StatusCode: 500}, err
	}

	body, _ := json.Marshal(q)
	return events.APIGatewayProxyResponse{
		StatusCode: 201,
		Headers:    map[string]string{"Content-Type": "application/json"},
		Body:       string(body),
	}, nil
}

func main() {
	cfg, err := config.LoadDefaultConfig(context.Background())
	if err != nil {
		panic(err)
	}
	client = dynamodb.NewFromConfig(cfg)
	lambda.Start(handler)
}
