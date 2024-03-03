resource "aws_vpc" "my_vpc" {
  cidr_block = var.cidr
}

resource "aws_subnet" "public_sub1" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public_sub2" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "private_sub1" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "us-east-1a"
}

resource "aws_subnet" "private_sub2" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.4.0/24"
  availability_zone       = "us-east-1b"
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.my_vpc.id
}

resource "aws_eip" "nat_elastic_ip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_elastic_ip.id
  subnet_id     = aws_subnet.public_sub1.id
}

resource "aws_route_table" "pub_route" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table" "priv_route" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public_sub1.id
  route_table_id = aws_route_table.pub_route.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.public_sub2.id
  route_table_id = aws_route_table.pub_route.id
}

resource "aws_route_table_association" "c" {
  subnet_id      = aws_subnet.private_sub1.id
  route_table_id = aws_route_table.priv_route.id
}

resource "aws_route_table_association" "d" {
  subnet_id      = aws_subnet.private_sub2.id
  route_table_id = aws_route_table.priv_route.id
}

resource "aws_security_group" "asg" {
  name   = "security_group"
  vpc_id = aws_vpc.my_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_s3_bucket" "s3" {
  bucket = "testing-bucket-deepenc-101"
}

resource "aws_instance" "inst" {
  ami                    = var.ami
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.asg.id]
  subnet_id              = aws_subnet.public_sub1.id
  user_data              = base64encode(file("userdata.sh"))
}

resource "aws_instance" "inst1" {
  ami                    = var.ami
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.asg.id]
  subnet_id              = aws_subnet.public_sub2.id
  user_data              = base64encode(file("userdata1.sh"))
}

resource "aws_lb" "mylb" {
  name               = "mylb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [aws_security_group.asg.id]
  subnets         = [aws_subnet.public_sub1.id, aws_subnet.public_sub2.id]
}

resource "aws_lb_target_group" "tg" {
  name     = "mytg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.my_vpc.id

  health_check {
    path = "/"
    port = "traffic-port"
  }
}

resource "aws_lb_target_group_attachment" "attach1" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.inst.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "attach2" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.inst1.id
  port             = 80
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.mylb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.tg.arn
    type             = "forward"
  }
}

output "loadbalncer" {
  value = aws_lb.mylb.name
}