resource "aws_cloudwatch_query_definition" "ses-deliveries" {
  name = "${var.environment}/email-deliveries-ses-tf"

  log_group_names = [local.log_group_name_delivered]

  query_string = <<EOF
fields @timestamp, mail.destination.0, mail.commonHeaders.subject
| sort @timestamp desc
EOF
}

resource "aws_cloudwatch_query_definition" "ses-problems" {
  name = "${var.environment}/email-bounces-ses-tf"

  log_group_names = [local.log_group_name_problem]

  query_string = <<EOF
fields @timestamp, mail.destination.0, bounce.bounceType, bounce.bounceSubType, mail.commonHeaders.subject
| sort @timestamp desc
EOF
}
