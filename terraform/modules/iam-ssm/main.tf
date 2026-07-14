# IAM role + instance profile for AWS Systems Manager Session Manager
# Attach to EC2s so you can connect without SSH bastion / public SSH.

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ssm" {
  name               = "${var.name}-ec2-ssm-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Optional: read-only ECR pull later for nodes
resource "aws_iam_role_policy_attachment" "extra" {
  for_each = toset(var.extra_policy_arns)

  role       = aws_iam_role.ssm.name
  policy_arn = each.value
}

resource "aws_iam_instance_profile" "ssm" {
  name = "${var.name}-ec2-ssm-profile"
  role = aws_iam_role.ssm.name
  tags = var.tags
}
