resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"
}

resource "aws_cloudwatch_log_group" "frontend" {
  name              = "/ecs/${var.project_name}-frontend"
  retention_in_days = 3
}

resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/${var.project_name}-backend"
  retention_in_days = 3
}

# Terraform owns the initial revision of each task definition only; CI/CD
# registers new revisions on every push (see the ignore_changes lifecycle
# block on each aws_ecs_service below).
resource "aws_ecs_task_definition" "frontend" {
  family                   = "${var.project_name}-frontend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([{
    name         = "frontend"
    image        = "${aws_ecr_repository.frontend.repository_url}:initial"
    portMappings = [{ containerPort = 8080, protocol = "tcp" }]
    environment = [
      # VPC's Amazon-provided DNS resolver, needed so nginx can resolve
      # $backend_host at request time (see frontend/nginx.conf.template).
      { name = "DNS_RESOLVER", value = "169.254.169.253" }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.frontend.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "frontend"
      }
    }
  }])
}

resource "aws_ecs_task_definition" "backend" {
  family                   = "${var.project_name}-backend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([{
    name         = "backend"
    image        = "${aws_ecr_repository.backend.repository_url}:initial"
    portMappings = [{ containerPort = 8080, protocol = "tcp" }]
    environment = [
      { name = "DB_SSLMODE", value = "require" }
    ]
    secrets = [
      { name = "DB_HOST", valueFrom = "${aws_secretsmanager_secret.db.arn}:host::" },
      { name = "DB_PORT", valueFrom = "${aws_secretsmanager_secret.db.arn}:port::" },
      { name = "DB_USER", valueFrom = "${aws_secretsmanager_secret.db.arn}:username::" },
      { name = "DB_PASSWORD", valueFrom = "${aws_secretsmanager_secret.db.arn}:password::" },
      { name = "DB_NAME", valueFrom = "${aws_secretsmanager_secret.db.arn}:dbname::" },
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.backend.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "backend"
      }
    }
  }])
}

resource "aws_ecs_service" "frontend" {
  name            = "${var.project_name}-frontend"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.frontend.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.frontend.arn
    container_name   = "frontend"
    container_port   = 8080
  }

  # No image exists in ECR until the first CI/CD push - don't block apply on it.
  wait_for_steady_state = false

  depends_on = [aws_lb_listener.http]

  lifecycle {
    ignore_changes = [task_definition]
  }
}

resource "aws_ecs_service" "backend" {
  name            = "${var.project_name}-backend"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend.arn
    container_name   = "backend"
    container_port   = 8080
  }

  wait_for_steady_state = false

  depends_on = [aws_lb_listener_rule.backend]

  lifecycle {
    ignore_changes = [task_definition]
  }
}
