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
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "project-bedrock-db-sg"
    Project = "karatu-2025-capstone"
  }
}

# 2. RDS Subnet Group
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "project-bedrock-db-subnet-group"
  subnet_ids = module.vpc.private_subnets

  tags = {
    Name    = "project-bedrock-db-subnet-group"
    Project = "karatu-2025-capstone"
  }
}

# 3. SSM Parameter for DB credentials
# Spec 4.2: "Database credentials must be stored securely — never hardcoded"
resource "aws_ssm_parameter" "db_password" {
  name        = "/bedrock/database/password"
  description = "Shared RDS password for Project Bedrock"
  type        = "SecureString"
  value       = "SecureBedrockPass2026!"

  tags = {
    Project = "karatu-2025-capstone"
  }
}

resource "aws_ssm_parameter" "db_username" {
  name        = "/bedrock/database/username"
  description = "Shared RDS username for Project Bedrock"
  type        = "SecureString"
  value       = "dbadmin"

  tags = {
    Project = "karatu-2025-capstone"
  }
}

# 4. Amazon RDS MySQL — for Catalog service
resource "aws_db_instance" "mysql" {
  identifier             = "bedrock-mysql"
  allocated_storage      = 20
  max_allocated_storage  = 50
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t4g.micro"

  # FIX: Was "orders" — catalog service expects database named "catalog"
  db_name  = "catalog"
  username = aws_ssm_parameter.db_username.value
  password = aws_ssm_parameter.db_password.value

  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  skip_final_snapshot    = true

  tags = {
    Name    = "bedrock-mysql"
    Project = "karatu-2025-capstone"
  }
}

# 5. Amazon RDS PostgreSQL — for Orders service
resource "aws_db_instance" "postgres" {
  identifier             = "bedrock-postgres"
  allocated_storage      = 20
  max_allocated_storage  = 50
  engine                 = "postgres"
  engine_version         = "15"
  instance_class         = "db.t4g.micro"

  # FIX: Was "retaildb" — orders service expects database named "orders"
  db_name  = "orders"
  username = aws_ssm_parameter.db_username.value
  password = aws_ssm_parameter.db_password.value

  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  skip_final_snapshot    = true

  tags = {
    Name    = "bedrock-postgres"
    Project = "karatu-2025-capstone"
  }
}

# 6. Kubernetes Secrets — injected from SSM, referenced by Helm charts
resource "kubernetes_secret" "catalog_db" {
  metadata {
    name      = "catalog-db"
    namespace = "retail-app"
  }

  data = {
    username = aws_ssm_parameter.db_username.value
    password = aws_ssm_parameter.db_password.value
  }

  depends_on = [kubernetes_namespace.retail_app]
}

resource "kubernetes_secret" "orders_db" {
  metadata {
    name      = "orders-db"
    namespace = "retail-app"
  }

  data = {
    username = aws_ssm_parameter.db_username.value
    password = aws_ssm_parameter.db_password.value
  }

  depends_on = [kubernetes_namespace.retail_app]
}
