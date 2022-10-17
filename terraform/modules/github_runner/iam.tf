resource "aws_iam_role" "runner" {
  name               = "runner-role-${var.environment}"
  assume_role_policy = templatefile("${path.module}/policies/instance_role_trust_policy.json", {})
  path               = "/gh-runner-${var.environment}/"
}

resource "aws_iam_instance_profile" "runner" {
  name = "runner-profile-${var.environment}"
  role = aws_iam_role.runner.name
  path = "/gh-runner-${var.environment}/"
}

resource "aws_iam_role_policy" "get_ssm_parameters" {
  name = "runner-ssm-parameters"
  role = aws_iam_role.runner.name
  policy = templatefile("${path.module}/policies/instance_ssm_parameters_policy.json",
    {
      arn = aws_ssm_parameter.cloudwatch_agent_config_runner.arn
    }
  )
}

locals {
  runner_iam_role_managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore", "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"]
}

resource "aws_iam_role_policy_attachment" "managed_policies" {
  count      = length(local.runner_iam_role_managed_policy_arns)
  role       = aws_iam_role.runner.name
  policy_arn = element(local.runner_iam_role_managed_policy_arns, count.index)
}
