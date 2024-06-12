terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region     = "ap-south-1"
  access_key = "AKIA2UC267BO3IZRUTIY"
  secret_key = "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"
}
resource "aws_s3_bucket" "vikasrawatengg" {
  bucket = "vikasrawatengg1"
  tags = {
    Name        = "Vikasrawatengg"
    Environment = "Dev"
  }
}
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/lambda-${local.file_sha}.zip"
}
resource "aws_s3_object" "object" {
  bucket = "vikasrawatengg1"
  key    = "lambda.zip"
  source = data.archive_file.lambda_zip.output_path
}
variable "function" {
  type    = string
  default = "vikas2-lambda"
}
resource "aws_iam_policy" "policy" {
  name        = "${var.function}-lambda_policy"
  path        = "/"
  description = "lambda test policy"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "logs:*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "lambda:*",
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}
resource "aws_iam_role" "Vikas_role" {
  name = "${var.function}_role"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = data.aws_iam_policy_document.source.json

}

data "aws_iam_policy_document" "source" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}
resource "aws_iam_role_policy_attachment" "Vikas-attach" {
  role       = aws_iam_role.Vikas_role.name
  policy_arn = aws_iam_policy.policy.arn
}
resource "aws_lambda_function" "vikas_lambda" {

  function_name = "${var.function}-lambda"
  role          = aws_iam_role.Vikas_role.arn
  handler       = "index.handler"
  s3_bucket     = aws_s3_bucket.vikasrawatengg.bucket
  s3_key        = aws_s3_object.object.key

  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  runtime = "nodejs18.x"
}
resource "aws_lambda_function_url" "vikas112_live" {
  function_name      = aws_lambda_function.vikas_lambda.function_name
  authorization_type = "NONE"

  cors {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST"]
  }
}

output "function_url" {
  value = aws_lambda_function_url.vikas112_live.function_url
}
terraform {
  backend "s3" {
    bucket = "test-cd-auto-lambda-deploy-backend-tfstate"
    key    = "vikasrawat/lambda.tfstate"
    region = "ap-south-1"
    # Configure the AWS Provider
    access_key = "AKIA2UC267BO3IZRUTIY"
    secret_key = "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"
  }
}
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.vikasrawatengg.id
 
  lambda_function {
    lambda_function_arn = aws_lambda_function.vikas_lambda.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "lambda.zip"
  }
 
  depends_on = [ aws_lambda_permission.with_s3 ]
}
 
resource "aws_lambda_permission" "with_s3" {
  statement_id  = "AllowS3Execution"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.vikas_lambda.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.vikasrawatengg.arn
}
locals {
  file_sha = join("", [for file in fileset("${path.module}/lambda", "*") : filesha256("${path.module}/lambda/${file}")])
 
}