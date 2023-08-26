locals {
  lt_demo_backend_url = local.env == "prod" ? "leaptalk-api.lf.binayabaral.com.np" : "leaptalk-api-dev.lf.binayabaral.com.np"
}

resource "aws_security_group" "lt_demo_ec2_sg" {
  name   = "lt-demo-ec2-sg-${local.env}"
  vpc_id = module.vpc.vpc_id

  ingress {
    description = "Allow SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTP access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, {
    Name = "lt-demo-ec2-sg-${local.env}"
  })
}

data "aws_iam_policy_document" "lt_demo_backend_ec2_iam_assume_role_policy" {
  statement {
    sid     = "AllowAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["ec2.amazonaws.com"]
      type        = "Service"
    }
  }
}

data "aws_iam_policy_document" "lt_demo_backend_ec2_iam_role_policy" {
  statement {
    sid = "AllowArtifactsBucketAccess"
    actions = [
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = [
      "arn:aws:s3:::com.leaptalk.${local.env}.demo.artifacts",
      "arn:aws:s3:::com.leaptalk.${local.env}.demo.artifacts/*"
    ]
  }
}

resource "aws_iam_role" "lt_demo_backend_ec2_role" {
  name               = "lt-demo-backend-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.lt_demo_backend_ec2_iam_assume_role_policy.json

  inline_policy {
    name   = "lt-demo-backend-ec2-iam-role-policy"
    policy = data.aws_iam_policy_document.lt_demo_backend_ec2_iam_role_policy.json
  }
}

resource "aws_iam_instance_profile" "lt_demo_backend_ec2_instance_profile" {
  name = "lt-demp-backend-ec2-instance-profile"
  role = aws_iam_role.lt_demo_backend_ec2_role.name
}

module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 4.3"

  name = "lt-demo-backend-${local.env}"

  ami                    = "ami-053b0d53c279acc90"
  instance_type          = "t3.micro"
  key_name               = "binaya-lf-us-east-1"
  vpc_security_group_ids = [aws_security_group.lt_demo_ec2_sg.id]
  subnet_id              = element(module.vpc.public_subnets, 1)
  iam_instance_profile   = aws_iam_instance_profile.lt_demo_backend_ec2_instance_profile.name

  user_data = base64encode(templatefile("${path.module}/scripts/setup-backend-ec2.sh.tpl", {
    env : local.env
  }))
  user_data_replace_on_change = true

  tags = merge(local.tags, {
    Name            = "lt-demo-backend-${local.env}"
    DeploymentGroup = local.env
  })
}

resource "aws_lb_target_group" "lt_demo_backend_tg" {
  name        = "lt-demo-backend-${local.env}"
  port        = 80
  target_type = "instance"
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_lb_target_group_attachment" "this" {
  target_group_arn = aws_lb_target_group.lt_demo_backend_tg.arn
  target_id        = module.ec2_instance.id
  port             = 80
}

resource "aws_lb_listener_rule" "rule" {
  listener_arn = element(module.alb.https_listener_arns, 1)
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lt_demo_backend_tg.arn
  }
  condition {
    host_header {
      values = [local.lt_demo_backend_url]
    }
  }
}

resource "aws_route53_record" "backend_route53_record" {
  name    = local.lt_demo_backend_url
  type    = "A"
  zone_id = data.aws_route53_zone.lf_binayabaral_com_np.zone_id

  alias {
    evaluate_target_health = false
    name                   = module.alb.lb_dns_name
    zone_id                = module.alb.lb_zone_id
  }
}
