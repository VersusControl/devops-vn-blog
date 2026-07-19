data "archive_file" "viewer_request" {
  type        = "zip"
  source_file = "${path.module}/function/viewer-request.js"
  output_path = "${path.module}/function/viewer-request.zip"
}

data "archive_file" "origin_request" {
  type        = "zip"
  source_file = "${path.module}/function/origin-request.js"
  output_path = "${path.module}/function/origin-request.zip"
}

data "archive_file" "origin_response" {
  type        = "zip"
  source_file = "${path.module}/function/origin-response.js"
  output_path = "${path.module}/function/origin-response.zip"
}

resource "aws_lambda_function" "viewer_request_function" {
  provider = aws.us_east_1

  function_name = "viewer-request-ab-testing"
  role          = aws_iam_role.lambda_edge.arn
  publish       = true

  handler          = "viewer-request.handler"
  runtime          = "nodejs20.x"
  filename         = data.archive_file.viewer_request.output_path
  source_code_hash = data.archive_file.viewer_request.output_base64sha256
}

resource "aws_lambda_function" "origin_request_function" {
  provider = aws.us_east_1

  function_name = "origin-request-ab-testing"
  role          = aws_iam_role.lambda_edge.arn
  publish       = true

  handler          = "origin-request.handler"
  runtime          = "nodejs20.x"
  filename         = data.archive_file.origin_request.output_path
  source_code_hash = data.archive_file.origin_request.output_base64sha256
}

resource "aws_lambda_function" "origin_response_function" {
  provider = aws.us_east_1

  function_name = "origin-response-ab-testing"
  role          = aws_iam_role.lambda_edge.arn
  publish       = true

  handler          = "origin-response.handler"
  runtime          = "nodejs20.x"
  filename         = data.archive_file.origin_response.output_path
  source_code_hash = data.archive_file.origin_response.output_base64sha256
}
