locals {
  lt_demo_web_app_alb_default_response = {
    status = "ok"
  }
}

resource "aws_security_group" "lt_demo_web_app_http" {
  name        = "lt_demo_lb_http_${local.env}"
  description = "LB Security Group ${local.env}"
  vpc_id      = module.vpc.vpc_id
  ingress {
    description = "Allow HTTPS Traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Allow HTTP Traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "Allow Outbound Traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow change in name
  lifecycle {
    create_before_destroy = true
  }
}

module "alb" {
  source             = "terraform-aws-modules/alb/aws"
  version            = "~> 8.3"
  name               = "lt-demo-lb-${local.env}"
  load_balancer_type = "application"
  internal           = false

  vpc_id                      = module.vpc.vpc_id
  subnets                     = module.vpc.public_subnets
  security_groups             = [aws_security_group.lt_demo_web_app_http.id]
  listener_ssl_policy_default = "ELBSecurityPolicy-FS-1-2-Res-2020-10"

  http_tcp_listeners = [
    {
      port        = 80
      protocol    = "HTTP"
      action_type = "redirect"
      redirect = {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  ]

  https_listeners = [
    {
      port            = 443
      protocol        = "HTTPS"
      certificate_arn = data.aws_acm_certificate.binaya_lf_certificate.arn
      action_type     = "fixed-response"
      fixed_response = {
        content_type = "application/json"
        message_body = jsonencode(local.lt_demo_web_app_alb_default_response)
        status_code  = "200"
      }
    }
  ]

  target_groups = [
    {
      name             = "lt-demo-lb-${local.env}"
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "instance"
    },
  ]
}
