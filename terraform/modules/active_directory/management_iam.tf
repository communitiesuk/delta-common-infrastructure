resource "aws_iam_role" "ad_management_role" {
  name = "ad_management_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

data "aws_iam_policy" "AmazonSSMManagedInstanceCore" {
  arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
data "aws_iam_policy" "AmazonSSMDirectoryServiceAccess" {
  arn = "arn:aws:iam::aws:policy/AmazonSSMDirectoryServiceAccess"
}

resource "aws_iam_role_policy_attachment" "ad_management_attach_1" {
  role       = aws_iam_role.ad_management_role.name
  policy_arn = data.aws_iam_policy.AmazonSSMManagedInstanceCore.arn
}

resource "aws_iam_role_policy_attachment" "ad_management_attach_2" {
  role       = aws_iam_role.ad_management_role.name
  policy_arn = data.aws_iam_policy.AmazonSSMDirectoryServiceAccess.arn
}

resource "aws_iam_instance_profile" "ad_management_profile" {
  name = "ad_management_profile"
  role = aws_iam_role.ad_management_role.name
}
