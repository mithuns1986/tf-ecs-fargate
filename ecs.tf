# ecs.tf

resource "aws_ecs_cluster" "main" {
  name = "${lower(var.env)}"-elk-cluster
}

data "template_file" "logstash" {
  template = file("./templates/ecs/logstash.json.tpl")

  vars = {
    app_image      = var.app_image
    app_port       = var.app_port
    fargate_cpu    = var.fargate_cpu
    fargate_memory = var.fargate_memory
    aws_region     = var.aws_region
  }
}

data "template_file" "elasticserach" {
  template = file("./templates/ecs/elasticsearch.json.tpl")

  vars = {
    app_image2      = var.app_image2
    app_port       = var.app_port
    fargate_cpu    = var.fargate_cpu
    fargate_memory = var.fargate_memory
    aws_region     = var.aws_region
  }
}

resource "aws_ecs_task_definition" "logstash" {
  family                   = "${lower(var.env)}"-logstash
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.fargate_cpu
  memory                   = var.fargate_memory
  container_definitions    = data.template_file.logstash.rendered
}

resource "aws_ecs_task_definition" "elasticsearch" {
  family                   = "${lower(var.env)}"-elasticsearch
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.fargate_cpu
  memory                   = var.fargate_memory
  container_definitions    = data.template_file.elasticsearch.rendered
}

resource "aws_ecs_service" "logstash" {
  name            = "${lower(var.env)}"-elk
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.logstash.arn
  desired_count   = var.app_count
  launch_type     = "FARGATE"
    network_configuration {
    security_groups  = [aws_security_group.ecs_tasks.id]
    subnets          = aws_subnet.private.*.id
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.app.id
    container_name   = "elk"
    container_port   = var.app_port
  }

  depends_on = [aws_alb_listener.front_end, aws_iam_role_policy_attachment.ecs_task_execution_role]
}

resource "aws_ecs_service" "main2" {
  name            = "myapp-service2"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.elasticsearch.arn
  desired_count   = var.app_count
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = [aws_security_group.ecs_tasks.id]
    subnets          = aws_subnet.private.*.id
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.app.id
    container_name   = "elk"
    container_port   = var.app_port
  }

  depends_on = [aws_alb_listener.front_end, aws_iam_role_policy_attachment.ecs_task_execution_role]
}