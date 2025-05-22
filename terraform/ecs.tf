// ecs.tf

# variable "db_host" {
#   description = "Hostname of the database"
#   type        = string
#   default     = "your-db-host"
# }

# variable "db_user" {
#   description = "Database username"
#   type        = string
#   default     = "shopware"
# }

# variable "db_name" {
#   description = "Database name"
#   type        = string
#   default     = "shopware"
# }

variable "dockware_image" {
  description = "Dockware image to run (including tag)"
  type        = string
  default     = "dockware/dev:latest"
}

resource "aws_security_group" "ecs" {
  name        = "shopware-ecs-sg"
  description = "Allow all ingress to ECS tasks (tune later)"
  vpc_id      = aws_vpc.main.id

  # allow all inbound for now
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "shopware-ecs-sg" }
}

resource "aws_ecs_cluster" "main" {
  name = "shopware-cluster"
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "shopware-ecs-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}


###############################
# 1. Grant SSM permissions   #
###############################
# Attach to aws_iam_role.ecs_task_execution_role
resource "aws_iam_role_policy_attachment" "exec_ssm" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "execution_secrets_policy" {
  name = "shopware-ecs-secret-access"
  role = aws_iam_role.ecs_task_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      #Resource = aws_secretsmanager_secret.db_password.arn
      Resource = "*"
    }]
  })
}

resource "aws_ecs_task_definition" "app" {
  family                   = "shopware"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn = aws_iam_role.ecs_task_execution_role.arn

  #################################################
  # 2. Tell Fargate to use Linux (for SSM agent) #
  #################################################
  # Inside your aws_ecs_task_definition "app" resource:
  runtime_platform {
    operating_system_family = "LINUX"
  }
  
  volume {
    name = "media-volume"
    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.media.id
      transit_encryption = "ENABLED"
    }
  }

  container_definitions = jsonencode([
    {
      name      = "shopware"
      image     = var.dockware_image
      essential = true
      user      = "root"

      # override entrypoint: if EFS media is empty, copy from image
      command = [
        "sh","-c",
        <<-EOC
          if [ ! -f /efs/media/.seeded ]; then
            echo "Seeding EFS with built-in media…"
            cp -a /var/www/html/public/media/. /efs/media/
            touch /efs/media/.seeded
          fi
          # swap out the original folder
          rm -rf /var/www/html/public/media
          ln -s /efs/media /var/www/html/public/media
          # now start Dockware as normal
          exec /opt/bin/dockware start
        EOC
      ]

      portMappings = [
        { containerPort = 80, hostPort = 80 }
      ]

      mountPoints = [{
        sourceVolume  = "media-volume"
        #containerPath = "/var/www/html/public/media"
        containerPath = "/efs/media"
        readOnly      = false
      }]

      environment = [
        { name = "DATABASE_URL", value = "mysql://${var.db_user}:${var.db_password}@${aws_db_instance.shopware.address}:${var.db_port}/${var.db_name}"},
        { name = "DATABASE_HOST" , value = aws_db_instance.shopware.address },
        { name = "DATABASE_PORT" , value = "3306" },
        # { name = "DATABASE_USER" , value = var.db_user },
        # { name = "DATABASE_NAME" , value = var.db_name }
      ]

      secrets = [
        # {
        #   name      = "DATABASE_PASSWORD"
        #   valueFrom = aws_secretsmanager_secret.db_password.arn
        # }
      ]

      healthCheck = {
      # check HTTP 200–399 on /, give it a 60s grace period
        command     = ["CMD-SHELL", "curl -f http://localhost/admin || exit 1"]
        interval    = 30          # poll every 30s
        timeout     = 5           # fail if no response in 5s
        retries     = 3           # try 3 times before marking unhealthy
        startPeriod = 60          # wait 60s before starting health checks
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/shopware"
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "app" {
  name            = "shopware-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [for sn in values(aws_subnet.private) : sn.id]
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "shopware"
    container_port   = 80
  }

  ############################################
  # 3. Enable Exec on your ECS Fargate service
  ############################################
  # Inside your aws_ecs_service "app" resource:
  enable_execute_command = true

  depends_on = [aws_lb_listener.http]
}




########################################################
# cloudwatch.tf
########################################################

# Create the /ecs/shopware log group for your ECS tasks
resource "aws_cloudwatch_log_group" "ecs_shopware" {
  name              = "/ecs/shopware"
  retention_in_days = 14          # keep logs for 2 weeks; adjust as you like
  tags = {
    Name = "shopware-ecs-logs"
  }
}
