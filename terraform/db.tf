# 1.1 DB subnet group so your RDS sits in your private subnets
resource "aws_db_subnet_group" "shopware" {
  name       = "shopware-db-subnets"
  subnet_ids = values(aws_subnet.private)[*].id

  tags = {
    Name = "shopware-db-subnets"
  }
}

# 1.2 Security group for RDS, allowing only your ECS SG on port 3306
resource "aws_security_group" "db" {
  name        = "shopware-db-sg"
  description = "Allow ECS tasks to talk to MySQL"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL from ECS"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "shopware-db-sg" }
}

# 1.3 The actual MySQL instance
resource "aws_db_instance" "shopware" {
  identifier              = "shopware-db"
  engine                  = "mysql"
  engine_version          = "8.0"
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  db_name                 = var.db_name
  username                = var.db_user
  password                = var.db_password        # ← pull from secrets.tf var
  db_subnet_group_name    = aws_db_subnet_group.shopware.name
  vpc_security_group_ids  = [aws_security_group.db.id]
  skip_final_snapshot     = true
  publicly_accessible     = true # REMOVE THIS LATER
  deletion_protection     = false

  tags = {
    Name = "shopware-db"
  }
}
