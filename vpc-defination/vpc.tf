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

resource "aws_instance" "app_server" {
  ami           = var.ami_id
  instance_type = var.instance_type
  vpc_security_group_ids = [ aws_security_group.ec2-sg.id ]
  subnet_id               = aws_subnet.public[1].id
  associate_public_ip_address = true

  tags = {
    Name = "ExampleAppServerInstance"
  }
}
resource "aws_security_group" "ec2-sg" {
  name        = "security-group"
  description = "allow inbound access to the Application task from NGINX"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  egress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }
}