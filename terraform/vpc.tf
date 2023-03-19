# Configure the AWS provider
provider "aws" {
  region = "us-east-1" 
}

#VPC
resource "aws_vpc" "vpc_demo" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "subnet1_demo" {
  vpc_id = aws_vpc.vpc_demo.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a" #Public1
}

resource "aws_subnet" "subnet2_demo" {
  vpc_id = aws_vpc.vpc_demo.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1b" #Public2
}

resource "aws_subnet" "subnet3_demo" {
  vpc_id = aws_vpc.vpc_demo.id
  cidr_block = "10.0.3.0/24"
  availability_zone = "us-east-1c" #Public2
}

resource "aws_internet_gateway" "igw_demo" {
  vpc_id = aws_vpc.vpc_demo.id
}   #internetGateway1


resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.vpc_demo.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_demo.id
  }
}

resource "aws_route_table_association" "subnet1" {
  subnet_id      = aws_subnet.subnet1_demo.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "subnet2" {
  subnet_id      = aws_subnet.subnet2_demo.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "subnet3" {
  subnet_id      = aws_subnet.subnet3_demo.id
  route_table_id = aws_route_table.public_rt.id
}

# PRIVATE 

resource "aws_eip" "nat_eip" {
  vpc = true
}

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.subnet3_demo.id
}


resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.vpc_demo.id
}


resource "aws_subnet" "private_subnet_1" {
  vpc_id = aws_vpc.vpc_demo.id
  cidr_block = "10.0.4.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = false
  tags = {
    Name = "private_subnet_1"
  }
}


resource "aws_subnet" "private_subnet_2" {
  vpc_id = aws_vpc.vpc_demo.id
  cidr_block = "10.0.5.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = false
  tags = {
    Name = "private_subnet_2"
  }
}

resource "aws_route" "private_nat_route" {
  route_table_id         = aws_route_table.private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gateway.id
}

resource "aws_route_table_association" "priv_subnet1" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "priv_subnet2" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_rt.id
}
# Create an ECS Fargate cluster
resource "aws_ecs_cluster" "cluster_demo" {
    name = "demo"
}

# Create an ALB 
resource "aws_lb" "lb_demo" {
  name = "lb-demo"
  internal = false
  load_balancer_type = "application"
  subnets = [aws_subnet.subnet1_demo.id, aws_subnet.subnet2_demo.id]
}

# Create a target group 
resource "aws_lb_target_group" "target_group_demo" {
  name = "target-group-demo"
  port = 3000
  protocol = "HTTP"
  vpc_id = aws_vpc.vpc_demo.id
  target_type = "ip"
}

# Create a listener to forward traffic to the target group
resource "aws_lb_listener" "listener_demo" {
  load_balancer_arn = aws_lb.lb_demo.arn
  port = 80
  protocol = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.target_group_demo.arn
  }
}

# Deploy Grafana
resource "aws_ecs_task_definition" "grafana_task" {
  family = "grafana"
  container_definitions = <<DEFINITION
[
  {
    "name": "grafana",
    "image": "grafana/grafana:latest",
    "portMappings": [
      {
        "containerPort": 3000,
        "hostPort": 0,
        "protocol": "tcp"
      }
    ]
  }
]
DEFINITION
}

resource "aws_ecs_service" "grafana_service" {
  name = "grafana-service"
  cluster = aws_ecs_cluster.cluster_demo.arn
  task_definition = aws_ecs_task_definition.grafana_task.arn
  desired_count = 1

  network_configuration {
    subnets = [aws_subnet.subnet1_demo.id, aws_subnet.subnet2_demo.id]
    security_groups = []
    assign_public_ip = true
  }
}

# Create a subnet group for the RDS instance
resource "aws_db_subnet_group" "grafana_db_subnet_group" {
  name        = "grafana-db-subnet-group"
  description = "Subnet group for Grafana RDS instance"
  subnet_ids  = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
}


resource "aws_security_group" "allow_vpc_sg" {
  name        = "allow_vpc"
  description = "Allow VPC"
  vpc_id      = aws_vpc.vpc_demo.id

  ingress {
    description      = "DB from VPC"
    from_port        = 3306
    to_port          = 3306
    protocol         = "tcp"
    cidr_blocks      = [aws_vpc.vpc_demo.cidr_block]
    ipv6_cidr_blocks = [aws_vpc.vpc_demo.ipv6_cidr_block]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_db"
  }
}


# Create a security group for the RDS instance
resource "aws_security_group" "grafana_db_security_group" {
  name_prefix = "grafana-db-sg-"

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [aws_security_group.allow_vpc_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "grafana-db-sg"
  }
}

# Create the RDS instance in the private subnets
resource "aws_db_instance" "grafana_db" {
  allocated_storage    = 10
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t2.micro"
  identifier           = "grafana-db"
  name                 = "grafana_db"
  username             = "grafana_user"
  password             = "grafana_password"
  db_subnet_group_name = aws_db_subnet_group.grafana_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.grafana_db_security_group.id]

  parameter_group_name = "default.mysql5.7"

  skip_final_snapshot = true

  tags = {
    Name = "grafana-db"
  }
}