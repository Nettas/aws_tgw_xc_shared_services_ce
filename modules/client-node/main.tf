############################################
# modules/client-node/main.tf
############################################

# ---------------------------------------------------------------------------
# Always use the latest Amazon Linux 2023 AMI via the public AWS SSM
# parameter, rather than hard-coding an AMI ID that will go stale and vary
# by region.
# ---------------------------------------------------------------------------
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-x86_64"
}

# ---------------------------------------------------------------------------
# Optional IAM role + instance profile for SSM Session Manager access.
# This avoids needing to open port 22 broadly just to reach a lab client
# node; it's created only when var.enable_ssm is true.
# ---------------------------------------------------------------------------
resource "aws_iam_role" "ssm" {
  count = var.enable_ssm ? 1 : 0

  name = "${var.name}-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ssm" {
  count = var.enable_ssm ? 1 : 0

  role       = aws_iam_role.ssm[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm" {
  count = var.enable_ssm ? 1 : 0

  name = "${var.name}-ssm-profile"
  role = aws_iam_role.ssm[0].name
}

# ---------------------------------------------------------------------------
# The client EC2 instance
# ---------------------------------------------------------------------------
resource "aws_instance" "this" {
  ami           = data.aws_ssm_parameter.al2023.value
  instance_type = var.instance_type
  subnet_id     = var.subnet_id

  vpc_security_group_ids = var.security_group_ids
  associate_public_ip_address = var.associate_public_ip
  key_name                     = var.key_name
  iam_instance_profile         = var.enable_ssm ? aws_iam_instance_profile.ssm[0].name : null

  # Small footprint - this is just a traffic source/destination for testing
  # reachability across the Transit Gateway, not a workload host.
  metadata_options {
    http_tokens = "required" # enforce IMDSv2
  }

  tags = merge(var.tags, {
    Name = var.name
  })
}
