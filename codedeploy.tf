resource "aws_iam_role" "codedeploy" {
  name = "lt-demo-codedeploy-role-${local.env}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "codedeploy.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "aws_code_deploy_role_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
  role       = aws_iam_role.codedeploy.name
}

resource "aws_codedeploy_app" "lt_demo_code_deploy_application" {
  name = "backend-${local.env}"
}

resource "aws_codedeploy_deployment_group" "lt_demo_code_deploy_group" {
  app_name              = aws_codedeploy_app.lt_demo_code_deploy_application.name
  deployment_group_name = local.env
  service_role_arn      = aws_iam_role.codedeploy.arn

  ec2_tag_set {
    ec2_tag_filter {
      type  = "KEY_AND_VALUE"
      key   = "DeploymentGroup"
      value = local.env
    }
  }
}

resource "aws_s3_bucket" "lt_demo_backend_artifacts_bucket" {
  bucket = "com.leaptalk.${local.env}.demo.artifacts"
}
