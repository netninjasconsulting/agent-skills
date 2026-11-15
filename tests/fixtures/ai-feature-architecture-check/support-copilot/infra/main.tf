# Test fixture.
provider "aws" {
  region = "us-east-1"
}

provider "aws" {
  alias  = "copy"
  region = "eu-west-1"
}

resource "aws_db_instance" "main" {
  identifier        = "support-copilot"
  engine            = "postgres"
  instance_class    = "db.t4g.medium"
  allocated_storage = 50
  storage_encrypted = true
}

# Copies the nightly snapshot, with the customers and the embeddings, to a second region.
resource "aws_db_instance_automated_backups_replication" "copy" {
  provider               = aws.copy
  source_db_instance_arn = aws_db_instance.main.arn
  retention_period       = 14
}
