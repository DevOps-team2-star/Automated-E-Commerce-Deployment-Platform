# Application Load Balancer (the "ELB" of the project) in front of Nginx on every k3s node.
resource "aws_security_group" "alb" {
  name        = "${var.name}-alb"
  description = "Public HTTP to the ALB"
  vpc_id      = var.vpc_id

  # Listener ports come from a variable: one ingress block is generated per port (dynamic block)
  dynamic "ingress" {
    for_each = var.public_ports
    content {
      description = "public ${ingress.value}"
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    description     = "To Nginx NodePort on the k3s nodes"
    from_port       = var.node_port
    to_port         = var.node_port
    protocol        = "tcp"
    security_groups = [var.node_sg_id]
  }

  tags = { Name = "${var.name}-alb" }
}

# Opens the NodePort on the node security group, but only for the ALB
resource "aws_vpc_security_group_ingress_rule" "nodes_from_alb" {
  security_group_id            = var.node_sg_id
  referenced_security_group_id = aws_security_group.alb.id
  ip_protocol                  = "tcp"
  from_port                    = var.node_port
  to_port                      = var.node_port
  description                  = "Nginx NodePort from the ALB"
}

resource "aws_lb" "this" {
  name               = "${var.name}-alb"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.subnet_ids
}

resource "aws_lb_target_group" "nginx" {
  name     = "${var.name}-nginx"
  port     = var.node_port
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/healthz"
    matcher             = "200"
    interval            = 10
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  deregistration_delay = 15
}

resource "aws_lb_target_group_attachment" "nodes" {
  for_each         = var.instance_ids
  target_group_arn = aws_lb_target_group.nginx.arn
  target_id        = each.value
  port             = var.node_port
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nginx.arn
  }
}
