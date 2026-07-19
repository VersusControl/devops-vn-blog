data "aws_iam_policy_document" "lambda_edge_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["edgelambda.amazonaws.com", "lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_edge" {
  name               = "AWSLambdaEdgeRole"
  path               = "/service-role/"
  assume_role_policy = data.aws_iam_policy_document.lambda_edge_assume.json
}

# The `inline_policy` block on aws_iam_role is deprecated — use a separate
# aws_iam_role_policy resource instead.
resource "aws_iam_role_policy" "lambda_edge" {
  name = "AWSLambdaEdgeInlinePolicy"
  role = aws_iam_role.lambda_edge.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = ["arn:aws:logs:*:*:*"]
      }
    ]
  })
}
