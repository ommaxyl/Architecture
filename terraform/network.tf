
data "aws_availability_zones" "azs" {}

# create a VPC (Virtual Private Cloud)
resource "aws_vpc" "fp-vpc" {
  cidr_block            = var.vpc_cidr
  enable_dns_hostnames  = true
  enable_dns_support    = true

  tags = {
    Name = "flask-vpc"
  }
}

# create an IGW (so resources can talk to the internet)
resource "aws_internet_gateway" "fp-igw" {
  vpc_id = aws_vpc.fp-vpc.id

  tags = {
    Name = "flask-igw"
  }
}

# create a Route Table for the VPC
resource "aws_route_table" "fp-rt-public" {
  vpc_id = aws_vpc.fp-vpc.id

  route {
    cidr_block = var.rt_wide_route
    gateway_id = aws_internet_gateway.fp-igw.id
  }

  tags = {
    Name = "flask-rt-public"
  }
}

# create a Default Route Table for the VPC
resource "aws_default_route_table" "flask-private-default" {
  default_route_table_id = aws_vpc.fp-vpc.default_route_table_id

  tags = {
    Name = "flask-rt-private-default"
  }
}

# create <count> number of public subnets in each availability zone
resource "aws_subnet" "fp-public-subnets" {
  count = 2
  cidr_block = var.public_cidrs[count.index]
  vpc_id = aws_vpc.fp-vpc.id
  map_public_ip_on_launch = true
  availability_zone = data.aws_availability_zones.azs.names[count.index]

  tags = {
    Name = "flask-tf-public-${count.index + 1}"
  }
}

# create <count> number of private subnets in each availability zone
resource "aws_subnet" "fp-private-subnets" {
  count             = 2
  cidr_block        = var.private_cidrs[count.index]
  # cidr_block        = cidrsubnet(aws_vpc.fp-vpc.cidr_block, 8, count.index)
  availability_zone = data.aws_availability_zones.azs.names[count.index]
  vpc_id            = aws_vpc.fp-vpc.id

  tags = {
    Name = "flask-tf-private-${count.index + 1}"
  }
}

# associate the public subnets with the public route table
resource "aws_route_table_association" "fp-public-rt-assc" {
  count = 2
  route_table_id = aws_route_table.fp-rt-public.id
  subnet_id = aws_subnet.fp-public-subnets.*.id[count.index]
}

# associate the private subnets with the public route table
resource "aws_route_table_association" "fp-private-rt-assc" {
  count = 2
  route_table_id = aws_route_table.fp-rt-public.id
  subnet_id = aws_subnet.fp-private-subnets.*.id[count.index]
}

# create security group
resource "aws_security_group" "fp-public-sg" {
  name = "fp-public-group"
  description = "access to public instances"
  vpc_id = aws_vpc.fp-vpc.id
}


