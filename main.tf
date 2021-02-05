provider "aws" {
  region = "us-east-2"
  access_key = "XXXXXXXXXXXXXXXX"
  secret_key = "XXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
}

# 1. Create vpc

resource "aws_vpc" "my_vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"
  tags = {
    Name = "my-vpc"
  }
}

# 2. Create Internet Gateway

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.my_vpc.id

}

# 3. Create Custom Route Table

resource "aws_route_table" "Public_RT" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "Public_RT"
  }
}

# 4. Create a Subnet 

resource "aws_subnet" "subnet_webapp" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-2a"

  tags = {
    Name = "webapp"
  }
}

# 5. Associate subnet with Route Table

resource "aws_route_table_association" "Route-Assoc" {
  subnet_id      = aws_subnet.subnet_webapp.id
  route_table_id = aws_route_table.Public_RT.id
}

resource "aws_security_group" "allow_web" {
  name        = "allow_webTraffic"
  description = "Allow Web inbound traffic"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    description = "Allow HTTPS Traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Allow HTTP Traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Allow SSH Traffic"
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

  tags = {
    Name = "allow_web_traffic"
  }
}

# 7. Create a network interface with an ip in the subnet that was created in step 4

resource "aws_network_interface" "webapp_Interface" {
  subnet_id       = aws_subnet.subnet_webapp.id
  private_ips     = ["10.0.1.100"]
  security_groups = [aws_security_group.allow_web.id]
}

# 8. Assign an elastic IP to the network interface created in step 7

# resource "aws_eip" "one" {
#   vpc                       = true
#   network_interface         = aws_network_interface.webapp_Interface.id
#   associate_with_private_ip = "10.0.1.100"
#   depends_on = [aws_internet_gateway.igw]
# }

resource "aws_eip" "one" {
  vpc = true

  instance                  = aws_instance.my_webapp.id
  associate_with_private_ip = "10.0.1.100"
  depends_on                = [aws_internet_gateway.igw]
}

# 9. Create Centos server and install/enable httpd

resource "aws_instance" "my_webapp" {
  ami           = "ami-00138b07206d4ceaf"
  instance_type = "t2.micro"
  availability_zone = "us-east-2a"
  key_name = "terraform"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.webapp_Interface.id
  }
  # associate_with_private_ip = "10.0.1.100"
  
  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install firewalld -y
              sudo systemctl start firewalld
              sudo firewall-cmd --permanent --add-port=443/tcp
              sudo firewall-cmd --permanent --add-port=80/tcp
              sudo firewall-cmd --permanent --add-port=22/tcp
              sudo firewall-cmd --permanent --add-service=http
              sudo firewall-cmd --permanent --add-service=https
              sudo firewall-cmd --reload
              sudo systemctl enable firewalld
              sudo yum install httpd -y
              sudo systemctl enable httpd
              sudo systemctl start httpd
              sudo bash -c 'echo Hello World > /var/www/html/index.html'
              EOF
  tags = {
    "Name" = "my_webapp_server"
  }
}