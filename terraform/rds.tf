# 1. Dedicated Security Group for RDS Databases
resource "aws_security_group" "db_sg" {
  name        = "project-bedrock-db-sg"
  description = "Allow inbound traffic strictly from EKS worker nodes"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "MySQL access from EKS nodes"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id]
  }

  ingress {
    description     = "PostgreSQL access from EKS nodes"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/16"]
  }

  tags = {
    Name = "project-bedrock-db-sg"
  }
}

# 2. RDS Subnet Group (Tells RDS to deploy strictly across our private network)
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "project-bedrock-db-subnet-group"
  subnet_ids = module.vpc.private_subnets

  tags = {
    Name = "project-bedrock-db-subnet-group"
  }
}

# 3. Amazon RDS MySQL Instance (For the microservice requiring MySQL)
resource "aws_db_instance" "mysql" {
  identifier             = "bedrock-mysql"
  allocated_storage      = 20
  max_allocated_storage  = 50
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t4g.micro"
  db_name                = "orders"
  username               = "dbadmin"
  password               = "SecureBedrockPass2026!"
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  skip_final_snapshot    = true
}

# 4. Amazon RDS PostgreSQL Instance (For the microservice requiring Postgres)
resource "aws_db_instance" "postgres" {
  identifier             = "bedrock-postgres"
  allocated_storage      = 20
  max_allocated_storage  = 50
  engine                 = "postgres"
  engine_version         = "15"
  instance_class         = "db.t4g.micro"
  db_name                = "retaildb"
  username               = "dbadmin"
  password               = "SecureBedrockPass2026!"
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  skip_final_snapshot    = true
}
