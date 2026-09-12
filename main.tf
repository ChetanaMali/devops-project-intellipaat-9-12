provider "aws" {
  region = "ap-south-1"
}

resource "aws_vpc" "quickbite_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = { Name = "quickbite-vpc" }
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.quickbite_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "ap-south-1a"
  tags = { Name = "quickbite-public-subnet" }
}

resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.quickbite_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-south-1a"
  tags = { Name = "quickbite-private-subnet" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.quickbite_vpc.id
  tags = { Name = "quickbite-igw" }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.quickbite_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "quickbite-public-rt" }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

###Add Security Groups####
resource "aws_security_group" "control_node_sg" {
  name   = "control-node-sg"
  vpc_id = aws_vpc.quickbite_vpc.id
  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # for exam; restrict in real use
  }
  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "app_server_sg" {
  name   = "app-server-sg"
  vpc_id = aws_vpc.quickbite_vpc.id
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.control_node_sg.id]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "db_server_sg" {
  name   = "db-server-sg"
  vpc_id = aws_vpc.quickbite_vpc.id
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app_server_sg.id]
  }
  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

###Add EC2 instances###
resource "aws_instance" "app_server" {
  ami                    = "ami-0f5ee92e2d63afc18" # Ubuntu 22.04, ap-south-1
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.app_server_sg.id]
  key_name               = "your-key-name"
  tags = { Name = "quickbite-app-server" }
}

resource "aws_instance" "db_server" {
  ami                    = "ami-0f5ee92e2d63afc18"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.private_subnet.id
  vpc_security_group_ids = [aws_security_group.db_server_sg.id]
  key_name               = "your-key-name"
  tags = { Name = "quickbite-db-server" }
}


###Output 
output "app_server_public_ip" {
  value = aws_instance.app_server.public_ip
}

output "db_server_private_ip" {
  value = aws_instance.db_server.private_ip
}