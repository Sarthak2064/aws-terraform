resource "aws_ecs_cluster" "main" {
  name = "ecs-cluster-nvir"
}

resource "aws_iam_role_policy" "ecs_task_execution_policy" {
  name = "ecs-task-execution-policy"
  role = aws_iam_role.ecs_task_execution_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "secretsmanager:GetSecretValue",
          "ssm:GetParameters"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:DescribeLogStreams",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:*:*:log-group:/ecs/prometheus:*"
      }
    ]
  })
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_lb" "alb" {
  name               = "main-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = var.public_subnets
}
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.elasticsearch_tg.arn
  }
}

resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Security group for ALB"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP traffic"
  }

  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow Prometheus traffic from ALB"
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow Grafana traffic from ALB"
  }

  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow GlitchTip traffic from ALB"
  }

  ingress {
    from_port   = 9200
    to_port     = 9200
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow ELK traffic"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }
}

#################################################### Prometheus ###################################################################

resource "aws_lb_target_group" "prometheus_tg" {
  name        = "prometheus-tg"
  port        = 9090
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"
  health_check {
    path = "/metrics"
    port = "traffic-port"
  }
}

resource "aws_lb_listener" "prometheus_http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 9090
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.prometheus_tg.arn
  }
}

resource "aws_ecs_service" "prometheus_service" {
  name             = "prometheus-service"
  cluster          = aws_ecs_cluster.main.id
  task_definition  = aws_ecs_task_definition.prometheus.arn
  desired_count    = 1
  launch_type      = "FARGATE"
  platform_version = "LATEST"

  network_configuration {
    subnets          = var.private_subnets
    security_groups  = [aws_security_group.alb_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.prometheus_tg.arn
    container_name   = "prometheus"
    container_port   = 9090
  }

  depends_on = [
    aws_lb_listener.http
  ]
}

resource "aws_ecs_task_definition" "prometheus" {
  family                   = "prometheus"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  memory                   = "512"
  cpu                      = "256"

  container_definitions = jsonencode([{
    name      = "prometheus"
    image     = "prom/prometheus:latest"
    essential = true
    portMappings = [{
      containerPort = 9090
      hostPort      = 9090
      protocol      = "tcp"
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.prometheus_logs.name
        "awslogs-region"        = "us-east-1"
        "awslogs-stream-prefix" = "prometheus"
      }
    }
  }])
}

resource "aws_cloudwatch_log_group" "prometheus_logs" {
  name = "/ecs/prometheus"
}


#################################################### Grafana ###################################################################

resource "aws_lb_target_group" "grafana_tg" {
  name        = "grafana-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"
  health_check {
    path = "/api/health"
    port = "traffic-port"
  }
}

resource "aws_lb_listener" "grafana_http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 3000
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.grafana_tg.arn
  }
}

resource "aws_ecs_service" "grafana_service" {
  name             = "grafana-service"
  cluster          = aws_ecs_cluster.main.id
  task_definition  = aws_ecs_task_definition.grafana.arn
  desired_count    = 1
  launch_type      = "FARGATE"
  platform_version = "LATEST"

  network_configuration {
    subnets          = var.private_subnets
    security_groups  = [aws_security_group.alb_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.grafana_tg.arn
    container_name   = "grafana"
    container_port   = 3000
  }

  depends_on = [
    aws_lb_listener.http
  ]
}

resource "aws_ecs_task_definition" "grafana" {
  family                   = "grafana"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  memory                   = "512"
  cpu                      = "256"

  container_definitions = jsonencode([{
    name      = "grafana"
    image     = "grafana/grafana:latest"
    essential = true
    portMappings = [{
      containerPort = 3000
      hostPort      = 3000
      protocol      = "tcp"
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.grafana_logs.name
        "awslogs-region"        = "us-east-1"
        "awslogs-stream-prefix" = "grafana"
      }
    }
  }])
}

resource "aws_cloudwatch_log_group" "grafana_logs" {
  name = "/ecs/grafana"
}


#################################################### Glitchtip ###################################################################

resource "aws_lb_target_group" "glitchtip_tg" {
  name        = "glitchtip-tg"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"
  health_check {
    path = "/"
    port = "traffic-port"
  }
}

resource "aws_lb_listener" "glitchtip_http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 8000
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.glitchtip_tg.arn
  }
}

resource "aws_ecs_service" "glitchtip_service" {
  name             = "glitchtip-service"
  cluster          = aws_ecs_cluster.main.id
  task_definition  = aws_ecs_task_definition.glitchtip.arn
  desired_count    = 1
  launch_type      = "FARGATE"
  platform_version = "LATEST"

  network_configuration {
    subnets          = var.private_subnets
    security_groups  = [aws_security_group.alb_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.glitchtip_tg.arn
    container_name   = "glitchtip"
    container_port   = 8000
  }

  depends_on = [
    aws_lb_listener.http
  ]
}

resource "aws_ecs_task_definition" "glitchtip" {
  family                   = "glitchtip"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  memory                   = "512"
  cpu                      = "256"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "glitchtip"
      image     = "glitchtip/glitchtip"
      essential = true
      portMappings = [
        {
          containerPort = 8000
          hostPort      = 8000
        }
      ]
      environment = [
        {
          name  = "DATABASE_URL"
          value = "postgres://postgre:Broomble123@database-1.c58gaqk06m5v.us-east-1.rds.amazonaws.com:5432/postgres"
        },
        {
          name  = "SECRET_KEY"
          value = "c4NQqyBI8_-80-xlpUKRyMk7yMjgfODxGyR2ZActm00GXGUudnfvsOFeindDy-8DWhw"
        },
        {
          name  = "EMAIL_URL"
          value = "consolemail://"
        },
        {
          name  = "PORT"
          value = "8000"
        },
        {
          name  = "GLITCHTIP_DOMAIN"
          value = "https://app.glitchtip.com"
        },
        {
          name  = "DEFAULT_FROM_EMAIL"
          value = "email@glitchtip.com"
        },
        {
          name  = "CELERY_WORKER_AUTOSCALE"
          value = "1,3"
        },
        {
          name  = "CELERY_WORKER_MAX_TASKS_PER_CHILD"
          value = "10000"
        }
      ]
    },
    {
      name      = "worker"
      image     = "glitchtip/glitchtip"
      essential = false
      command   = ["./bin/run-celery-with-beat.sh"]
      environment = [
        {
          name  = "DATABASE_URL"
          value = "postgres://postgre:Broomble123@database-1.c58gaqk06m5v.us-east-1.rds.amazonaws.com:5432/postgres"
        },
        {
          name  = "SECRET_KEY"
          value = "c4NQqyBI8_-80-xlpUKRyMk7yMjgfODxGyR2ZActm00GXGUudnfvsOFeindDy-8DWhw"
        },
        {
          name  = "PORT"
          value = "8000"
        },
        {
          name  = "EMAIL_URL"
          value = "consolemail://"
        },
        {
          name  = "GLITCHTIP_DOMAIN"
          value = "https://app.glitchtip.com"
        },
        {
          name  = "DEFAULT_FROM_EMAIL"
          value = "email@glitchtip.com"
        },
        {
          name  = "CELERY_WORKER_AUTOSCALE"
          value = "1,3"
        },
        {
          name  = "CELERY_WORKER_MAX_TASKS_PER_CHILD"
          value = "10000"
        }
      ]
    }
  ])
}

resource "aws_cloudwatch_log_group" "glitchtip_logs" {
  name = "/ecs/glitchtip"
}

#################################################### ELk ###################################################################



resource "aws_lb_target_group" "elasticsearch_tg" {
  name        = "elasticsearch-tg"
  port        = 9200
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"
  health_check {
    path = "/_cluster/health"
    port = "traffic-port"
  }
}

resource "aws_lb_listener" "elasticsearch_http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 9200
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.elasticsearch_tg.arn
  }
}

resource "aws_ecs_service" "elasticsearch_service" {
  name             = "elasticsearch-service"
  cluster          = aws_ecs_cluster.main.id
  task_definition  = aws_ecs_task_definition.elasticsearch.arn
  desired_count    = 1
  launch_type      = "FARGATE"
  platform_version = "LATEST"

  network_configuration {
    subnets          = var.private_subnets
    security_groups  = [aws_security_group.alb_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.elasticsearch_tg.arn
    container_name   = "elasticsearch"
    container_port   = 9200
  }

  depends_on = [
    aws_lb_listener.elasticsearch_http
  ]
}

resource "aws_ecs_task_definition" "elasticsearch" {
  family                   = "elasticsearch"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  memory                   = "2048"
  cpu                      = "1024"

  container_definitions = jsonencode([{
    name      = "elasticsearch"
    image     = "docker.elastic.co/elasticsearch/elasticsearch:7.10.1"
    essential = true
    portMappings = [{
      containerPort = 9200
      hostPort      = 9200
      protocol      = "tcp"
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.elasticsearch_logs.name
        "awslogs-region"        = "us-east-1"
        "awslogs-stream-prefix" = "elasticsearch"
      }
    }
  }])
}

resource "aws_cloudwatch_log_group" "elasticsearch_logs" {
  name = "/ecs/elasticsearch"
}

