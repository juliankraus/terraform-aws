provider "aws" {
  region = "eu-central-1"
}

variable vpc_cidr_block {}
variable subnet_cidr_block {}
variable avail_zone {}
variable env_prefix {}
variable my_ip {}
variable instance_type {}
variable ssh_key_name {}
variable public_key_location {}

resource "aws_vpc" "myapp-vpc" {
  cidr_block = var.vpc_cidr_block
  tags = {
    Name: "${var.env_prefix}-vpc"
  }
}

resource "aws_subnet" "myapp-subnet-1" {
  vpc_id = aws_vpc.myapp-vpc.id
  cidr_block = var.subnet_cidr_block
  availability_zone = var.avail_zone
  tags = {
    Name: "${var.env_prefix}-subnet-1"
  }
}

/*
# Custom route table
resource "aws_route_table" "myapp-route-table" {
  vpc_id = aws_vpc.myapp-vpc.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.myapp-igw.id
  }

  tags = {
    Name: "${var.env_prefix}-rtb"
  }
}

# Associate custom route table with a subnet
resource "aws_route_table_association" "a-rtb-subnet" {
  subnet_id = aws_subnet.myapp-subnet-1.id
  route_table_id = aws_route_table.myapp-route-table.id
}
*/

resource "aws_internet_gateway" "myapp-igw" {
  vpc_id = aws_vpc.myapp-vpc.id
  tags = {
    Name: "${var.env_prefix}-igw"
  }
}

# Configure default route table
resource "aws_default_route_table" "default-rtb" {
  default_route_table_id = aws_vpc.myapp-vpc.default_route_table_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.myapp-igw.id
  }

  tags = {
    Name: "${var.env_prefix}-default-rtb"
  }
}

/*
# Custom security group
resource "aws_security_group" "myapp-sg" {
  name = "myapp-sg"
  vpc_id = aws_vpc.myapp-vpc.id

  ingress {
    from_port = 22
    to_port = 22
    protocol = "TCP"
    cidr_blocks = [ var.my_ip ]
  }

  ingress {
    from_port = 8080
    to_port = 8080
    protocol = "TCP"
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [ "0.0.0.0/0" ]
    prefix_list_ids = []
  }
  
  tags = {
    Name: "${var.env_prefix}-sg"
  }
}
*/

# Configure default security group
resource "aws_default_security_group" "default-sg" {
  vpc_id = aws_vpc.myapp-vpc.id

  ingress {
    from_port = 22
    to_port = 22
    protocol = "TCP"
    cidr_blocks = [ var.my_ip ]
  }

  ingress {
    from_port = 8080
    to_port = 8080
    protocol = "TCP"
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [ "0.0.0.0/0" ]
    prefix_list_ids = []
  }
  
  tags = {
    Name: "${var.env_prefix}-default-sg"
  }
}

# Dynamically fetch latest amazon linux image id
data "aws_ami" "latest-amazon-linux-image" {
  most_recent = true
  owners = [ "amazon" ]
  filter {
    name = "name"
    values = [ "amzn2-ami-kernel-*-gp2" ]
  }
  filter {
    name = "virtualization-type"
    values = [ "hvm" ]
  }
  filter {
    name = "architecture"
    values = [ "x86_64" ]
  }
}

output "aws_ami_id" {
  value = data.aws_ami.latest-amazon-linux-image.id
}

# Generate a SSH private key from own public key
resource "aws_key_pair" "ssh-key" {
  key_name = "server-key"
  public_key = file(var.public_key_location)
}

# Generate EC2 instance
resource "aws_instance" "myapp-server" {
  ami = data.aws_ami.latest-amazon-linux-image.id
  instance_type = var.instance_type

  subnet_id = aws_subnet.myapp-subnet-1.id
  vpc_security_group_ids = [ aws_default_security_group.default-sg.id ]
  availability_zone = var.avail_zone

  associate_public_ip_address = true
  key_name = aws_key_pair.ssh-key.key_name

  user_data = <<EOF
                #!/bin/bash
                sudo yum update -y && sudo yum install -y docker
                sudo systemctl enable docker && sudo systemctl start docker
                sudo usermod -aG docker ec2-user
                docker run -p 8080:80 nginx
              EOF

  user_data_replace_on_change = true

  tags = {
    Name: "${var.env_prefix}-server"
  }
}

output "ec2_public_ip" {
  value = aws_instance.myapp-server.public_ip
}
