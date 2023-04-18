resource "aws_security_group" "jaspersoft_db" {
  name        = "jaspersoft-db-sg-${var.environment}"
  vpc_id      = var.vpc.id
  description = "Allow ingress from VPC"
}

resource "aws_security_group_rule" "database_from_instance" {
  security_group_id        = aws_security_group.jaspersoft_db.id
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = 5432
  to_port                  = 5432
  source_security_group_id = aws_security_group.jaspersoft_server.id
  description              = "jaspersoft to database"
}

resource "aws_db_subnet_group" "jaspersoft" {
  name       = "${var.environment}-jaspersoft"
  subnet_ids = var.database_subnets[*].id
}

resource "random_password" "jaspersoft_db" {
  length  = 32
  special = false
}

# tfsec:ignore:aws-ssm-secret-use-customer-key
resource "aws_secretsmanager_secret" "jaspersoft_db_password" {
  name                    = "tf-managed-jaspersoft-db-password-${var.environment}"
  description             = "Managed by Terraform, do not change manually. Password for jaspersoft user in jaspersoft RDS database for ${var.environment} environment."
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "jaspersoft_db_password" {
  secret_id     = aws_secretsmanager_secret.jaspersoft_db_password.id
  secret_string = random_password.jaspersoft_db.result
}

# We do not expect to need to debug jaspersoft performance issues, and can enable RDS Performance Insights later if we need to.
# The AVD-AWS code is an ignore for 'Instance does not have IAM Authentication enabled' rule
# tfsec:ignore:aws-rds-enable-performance-insights
# tfsec:ignore:AVD-AWS-0176
resource "aws_db_instance" "jaspersoft" {
  identifier                = "${var.environment}-jaspersoft"
  db_name                   = "postgres" # JasperReports likes to create its own database anyway so leave this as the default
  instance_class            = "db.t3.micro"
  engine                    = "postgres"
  engine_version            = "14.4"
  allocated_storage         = 10 # GB
  storage_encrypted         = true
  username                  = "jaspersoft"
  password                  = random_password.jaspersoft_db.result
  db_subnet_group_name      = aws_db_subnet_group.jaspersoft.name
  multi_az                  = true
  network_type              = "IPV4"
  port                      = 5432
  vpc_security_group_ids    = [aws_security_group.jaspersoft_db.id]
  publicly_accessible       = false
  skip_final_snapshot       = false
  final_snapshot_identifier = "jaspersoft-db-final-${var.environment}"
  maintenance_window        = "Tue:03:00-Tue:05:00"
  backup_window             = "01:00-02:00"
  backup_retention_period   = 14
  deletion_protection       = true
}

resource "aws_route53_record" "jaspersoft_db" {
  zone_id = var.private_dns.zone_id
  name    = "jaspersoft-db.${var.private_dns.base_domain}"
  type    = "CNAME"
  ttl     = 300
  records = [aws_db_instance.jaspersoft.address]
}
