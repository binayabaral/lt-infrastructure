resource "aws_s3_bucket" "lt_demo_test_bucket" {
  bucket = "com.leaptalk.${local.env}.demo.artifacts.test"
}
