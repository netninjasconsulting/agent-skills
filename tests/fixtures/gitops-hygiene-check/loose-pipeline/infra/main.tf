provider "aws" {
  region = "eu-central-1"
}

resource "aws_s3_bucket" "site" {
  bucket = "loose-pipeline-prod"
}
