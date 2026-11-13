terraform {
  backend "s3" {
    bucket       = "parcel-api-terraform-state"
    key          = "parcel-api/terraform.tfstate"
    region       = "eu-central-1"
    use_lockfile = true
  }
}

provider "aws" {
  region = "eu-central-1"
}

variable "environment" {
  type    = string
  default = "production"
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
}

resource "aws_db_instance" "main" {
  identifier              = "parcel-api-${var.environment}"
  engine                  = "postgres"
  engine_version          = "17"
  instance_class          = "db.t4g.micro"
  allocated_storage       = 20
  multi_az                = false
  backup_retention_period = 7
  deletion_protection     = false
  storage_encrypted       = true
}

resource "aws_secretsmanager_secret" "stripe" {
  name = "parcel-api/stripe-secret-key"
}

resource "aws_s3_bucket" "exports" {
  bucket = "parcel-api-exports-${var.environment}"
}

resource "aws_lambda_function" "api" {
  function_name = "parcel-api"
  role          = aws_iam_role.lambda.arn
  runtime       = "nodejs22.x"
  handler       = "server.handler"
  filename      = "../dist/api.zip"
  memory_size   = 512
  timeout       = 15

  environment {
    variables = {
      DATABASE_URL  = "resolved-at-deploy"
      EXPORT_BUCKET = aws_s3_bucket.exports.bucket
    }
  }
}

resource "aws_apigatewayv2_api" "http" {
  name          = "parcel-api"
  protocol_type = "HTTP"
  target        = aws_lambda_function.api.arn
}

resource "aws_lambda_function" "nightly_report" {
  function_name = "parcel-nightly-report"
  role          = aws_iam_role.lambda.arn
  runtime       = "nodejs22.x"
  handler       = "report.handler"
  filename      = "../dist/report.zip"
  timeout       = 300

  environment {
    variables = {
      EXPORT_BUCKET = aws_s3_bucket.exports.bucket
    }
  }
}

resource "aws_cloudwatch_event_rule" "nightly_report" {
  name                = "parcel-nightly-report"
  schedule_expression = "cron(0 2 * * ? *)"
}

resource "aws_cloudwatch_event_target" "nightly_report" {
  rule = aws_cloudwatch_event_rule.nightly_report.name
  arn  = aws_lambda_function.nightly_report.arn
}
