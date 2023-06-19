resource "aws_cloudwatch_query_definition" "ses-deliveries" {
  name = "${var.environment}/ses-deliveries-tf"

  log_group_names = [local.log_group_name_delivered]

  query_string = <<EOF
fields @timestamp, mail.destination.0, mail.commonHeaders.subject
EOF
}

resource "aws_cloudwatch_query_definition" "ses-problems" {
  name = "${var.environment}/ses-problems-tf"

  log_group_names = [local.log_group_name_problem]

  query_string = <<EOF
fields @timestamp, mail.destination.0, bounce.bounceSubType, mail.commonHeaders.subject
EOF
}
