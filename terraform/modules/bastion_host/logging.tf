resource "aws_ssm_parameter" "cloudwatch_agent_config" {
  count = var.log_group_name == null ? 0 : 1

  # CloudWatchAgentServerPolicy grants permission to read parameters with the prefix "AmazonCloudWatch-"
  name = "AmazonCloudWatch-${var.name_prefix}-bastion"
  type = "String"
  value = jsonencode({
    logs = {
      logs_collected = {
        files = {
          collect_list = [
            {
              log_group_name  = var.log_group_name
              log_stream_name = "{instance_id}-ssh"
              file_path       = "/var/log/secure"
            },
            {
              log_group_name  = var.log_group_name
              log_stream_name = "{instance_id}-changelog"
              file_path       = "/var/log/bastion/changelog.log"
            }
          ]
        }
      }
    }
  })
}
