resource "aws_vpc" "my_vpc" {
  cidr_block              = var.cidr_block
  enable_dns_support      = true
  enable_dns_hostnames    = true

  tags = {
      "Name"              = var.vpc_name
  }
}

resource "aws_internet_gateway" "default" {
  vpc_id                  =   aws_vpc.my_vpc.id
}
####   Private Routes ####
resource "aws_route_table" "private" {
  count                   = length(var.private_subnet_cidr_blocks)
  vpc_id                  = aws_vpc.my_vpc.id
}

resource "aws_route" "private" {
  count                   = length(var.private_subnet_cidr_blocks)
  route_table_id          = aws_route_table.private[count.index].id
  destination_cidr_block  = "0.0.0.0/0"
  nat_gateway_id          = aws_nat_gateway.default[count.index].id
}

#### Public Routes ####
resource "aws_route_table" "public" {
  #count                   = length(var.public_subnet_cidr_blocks)
  vpc_id                  = aws_vpc.my_vpc.id
}

resource "aws_route" "public" {
  route_table_id          = aws_route_table.public.id
  destination_cidr_block  = "0.0.0.0/0"
  gateway_id              = aws_internet_gateway.default.id
}

#### Subnet Defination ####
resource "aws_subnet" "private" {
  count                   = length(var.private_subnet_cidr_blocks)
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = var.private_subnet_cidr_blocks[count.index]
  availability_zone       = var.availability_zones[count.index]
  tags = {
      "Name"              = "PrivateSubnet-0${count.index+1},${var.availability_zones[count.index]}"
  }
}

resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidr_blocks)
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = var.public_subnet_cidr_blocks[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true
  tags = {
      "Name"              = "PublicSubnet-0${count.index+1},${var.availability_zones[count.index]}"
  }
}

#### Route Table Association ####
resource "aws_route_table_association" "private" {
  count                   = length(var.private_subnet_cidr_blocks)
  subnet_id               = aws_subnet.private[count.index].id
  route_table_id          = aws_route_table.private[count.index].id 
}

resource "aws_route_table_association" "public" {
  count                   = length(var.public_subnet_cidr_blocks)
  subnet_id               = aws_subnet.public[count.index].id
  route_table_id          = aws_route_table.public.id 
}

#### NAT GATEWAY ####
resource "aws_eip" "nat" {
  count                   = length(var.public_subnet_cidr_blocks)
  vpc                     = true
}

resource "aws_nat_gateway" "default" {
  depends_on              = ["aws_internet_gateway.default"]

  count                   = length(var.public_subnet_cidr_blocks)
  allocation_id           = aws_eip.nat[count.index].id
  subnet_id               = aws_subnet.public[count.index].id
}

## EC2 Instance
resource "aws_launch_configuration" "app_server" {
name_prefix = "app_server-"  
image_id           = var.ami_id
instance_type = var.instance_type
#count         = 2
key_name   = "parvez-workstation"
security_groups = [ aws_security_group.ec2-sg.id ]
#subnet_id               = aws_subnet.public[1].id
associate_public_ip_address = true

user_data     = <<-EOF
                  #!/bin/bash
                  sudo su
                  yum -y install httpd
                  echo "<p> My Instance! </p>" >> /var/www/html/index.html
                  sudo systemctl enable httpd
                  sudo systemctl start httpd
                  EOF

lifecycle {
  create_before_destroy = true
}
}

## EC2 Security Group
resource "aws_security_group" "ec2-sg" {
name        = "security-group"
description = "Allow HTTP traffic to instances through Elastic Load Balancer"
vpc_id      = aws_vpc.my_vpc.id

ingress {
  protocol    = "-1"
  from_port   = 0
  to_port     = 0
  cidr_blocks = [ "0.0.0.0/0" ]
}

egress {
  protocol    = "-1"
  from_port   = 0
  to_port     = 0
  cidr_blocks = ["0.0.0.0/0"]
}
}

## Load Balanacer
resource "aws_elb" "web_elb" {
name               = "web-elb"
#internal           = false
security_groups    = [ aws_security_group.ec2-sg.id ]
subnets            = aws_subnet.public.*.id

cross_zone_load_balancing   = true

health_check {
  healthy_threshold = 2
  unhealthy_threshold = 2
  timeout = 3
  interval = 10
  target = "HTTP:80/"
}
listener {
  lb_port = 80
  lb_protocol = "http"
  instance_port = "80"
  instance_protocol = "http"
}
}
## Auto Scaling Group

resource "aws_autoscaling_group" "app_server" {
  name = "${aws_launch_configuration.app_server.name}-asg"

  min_size             = 1
  desired_capacity     = 2
  max_size             = 4
  
  health_check_type    = "ELB"
  load_balancers = [
    aws_elb.web_elb.id
  ]

  launch_configuration = aws_launch_configuration.app_server.name

  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupTotalInstances"
  ]

  metrics_granularity = "1Minute"

  vpc_zone_identifier  = [
    #aws_subnet.public_us_west_1b.id,
    #aws_subnet.public_us_west_1c.id
    aws_subnet.public[1].id,
    aws_subnet.public[0].id
  ]

  # Required to redeploy without an outage.
  lifecycle {
    create_before_destroy = true
  }

  tag {
    key                 = "Name"
    value               = "app_server"
    propagate_at_launch = true
  }
}

output "elb_dns_name" {
    value = aws_elb.web_elb.dns_name
}