resource "aws_db_subnet_group" "lt_demo_db_subnet_group" {
  name       = "lt-demo-db-subnet-group-${local.env}"
  subnet_ids = module.vpc.public_subnets

  tags = merge(local.tags, {
    Name = "lt-demo-db-subnet-group-${local.env}"
  })
}

resource "aws_security_group" "lt_demo_rds_sg" {
  name   = "lt-demo-rds-sg-${local.env}"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, {
    Name = "lt-demo-rds-sg-${local.env}"
  })
}

resource "aws_db_parameter_group" "lt_demo_db_parameter_group" {
  name   = "lt-demo-db-parameter-group-${local.env}"
  family = "postgres15"

  parameter {
    name  = "log_connections"
    value = "1"
  }
}

resource "aws_db_instance" "lt_demo_app_rds" {
  identifier             = "lt-demo-app-rds-${local.env}"
  instance_class         = "db.t3.micro"
  allocated_storage      = 5
  engine                 = "postgres"
  engine_version         = "15.3"
  username               = "binaya"
  password               = "applebanana"
  db_subnet_group_name   = aws_db_subnet_group.lt_demo_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.lt_demo_rds_sg.id]
  parameter_group_name   = aws_db_parameter_group.lt_demo_db_parameter_group.name
  publicly_accessible    = true
  skip_final_snapshot    = true

  tags = merge(local.tags, {
    Name = "lt-demo-app-rds-${local.env}"
  })
}
