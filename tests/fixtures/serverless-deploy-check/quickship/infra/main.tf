resource "aws_lambda_function" "resize" {
  function_name                  = "quickship-resize"
  role                           = aws_iam_role.resize.arn
  handler                        = "index.handler"
  runtime                        = "nodejs24.x"
  architectures                  = ["arm64"]
  memory_size                    = 512
  timeout                        = 30
  reserved_concurrent_executions = 5
  filename                       = "resize.zip"
}

resource "aws_iam_role" "resize" {
  name               = "quickship-resize"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy" "resize" {
  role = aws_iam_role.resize.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:PutObject"]
      Resource = "arn:aws:s3:::quickship-labels/*"
    }]
  })
}

resource "aws_cloudwatch_log_group" "resize" {
  name              = "/aws/lambda/quickship-resize"
  retention_in_days = 30
}

locals {
  handover_note = <<-EOT
    Registry login for the resize build.
    FIXTUREVALUE-terraform-heredoc-01
  EOT
}
