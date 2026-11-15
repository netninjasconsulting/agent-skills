# Test fixture. One account holds everything.
provider "aws" {
  region = "us-east-1"
}

resource "aws_iam_role" "deploy" {
  name               = "parcel-desk-deploy"
  assume_role_policy = data.aws_iam_policy_document.github.json
}

resource "aws_s3_bucket" "parcels" {
  bucket = "parcel-desk-prod"
}
