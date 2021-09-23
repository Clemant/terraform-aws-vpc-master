### Module Main

provider "aws" {
  region = var.aws_region
}

### Step 1: Creation d'un VPC

resource "aws_vpc" "vpc" {
  cidr_block       = var.vpc_cibr
  tags = {
    Name =  "${var.vpc_name}-vpc"
    Environment = "prod"
    Terraform = "true"
  }
}
### Step 2: Creation des subnets public 
resource "aws_subnet" "public" {
  for_each = toset(var.vpc_azs)
  vpc_id     = aws_vpc.vpc.id
  availability_zone ="${var.aws_region}${each.value}"
  cidr_block = cidrsubnet(var.vpc_cibr,4, index(var.vpc_azs, each.value) )
  map_public_ip_on_launch = true
   tags = {
    Name = "${var.vpc_name}-public-${var.aws_region}${each.value}"
  }
}

### Step 3: Creation des subnets private
resource "aws_subnet" "private" {
  for_each = toset(var.vpc_azs)
  vpc_id     = aws_vpc.vpc.id
  availability_zone ="${var.aws_region}${each.value}"
  cidr_block = cidrsubnet(var.vpc_cibr,4, 15-index(var.vpc_azs, each.value) )
  map_public_ip_on_launch = false
   tags = {
    Name = "${var.vpc_name}-private-${var.aws_region}${each.value}"
  }
}

### Step 4: Creation d'un internet gateway
resource "aws_internet_gateway" "gateway" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "${var.vpc_name}-igw"
   }
}

### Step 5: Récuperation d'une AMI

data "aws_ami" "ami" {
  most_recent = true
  name_regex = "^amzn-ami-vpc-nat-2018.03.0.2021*"
  owners = ["amazon"]
}

### Step 6: Creation de Security Group
resource "aws_security_group" "security_group" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.vpc.id
  tags = {
    Name = "${var.vpc_name}-sg"
  }
}

### Step 7: Creation d'une règle de Security Group (Ingress)
resource "aws_security_group_rule" "security_group_rule_ingress" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.security_group.id
  cidr_blocks       =  [for subnet in aws_subnet.private : subnet.cidr_block]
}

### Step 7.1: Creation d'une règle de Security Group (e)
resource "aws_security_group_rule" "security_group_rule_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.security_group.id
}

### Step 8: Creation d'un key pair
resource "aws_key_pair" "key_pair" {
  key_name   = "deployer-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCgb4KJX+Rtdm4rfAllGeviFxt1ONlj8zwbHaaoCIbpBr52re3xT1LND/tiQyool0qL9iZQIjd89//EPXNzlvNPXM+XJhN5A2zgTmHanAoJt+6N6LDJRCUYfRI9ooJzkWsraB7IqAPe1/lxb8OH0LZjS+OYoGn/0zVzlEeKZlSJSSf+GF98AHKcWxvUVpU/E++Q7fmsHdCCYDzxf6SGpUzgVC+WiIJN/u+c2uAIF0ZJ/mdgBZhOi85ISuVfnXeYKvxVfZry7jsLjVCJrLOBBdWCY5twHgsCdjKWDqkfVRVNoam/2e+QKsJnyxg8ajlYLVrQCiIXgf9S6KjMc4VtvOqP"
  tags  = {
    Name = "${var.vpc_name}-key_pair"
  }
}

### Step 9: Creation d'une instance
resource "aws_instance" "instance"{
  for_each = toset(var.vpc_azs) 
  ami = data.aws_ami.ami.id
  instance_type = "t2.micro"
  security_groups = [aws_security_group.security_group.id]
  key_name = aws_key_pair.key_pair.id
  subnet_id = aws_subnet.public[each.value].id
  source_dest_check = false
  tags = {
    Name = "${var.vpc_name}-instance-${each.value}"
  }
}

### Step 9: Creation d'une instance (Private)
resource "aws_instance" "instance_private"{
  for_each = toset(var.vpc_azs) 
  ami = data.aws_ami.ami.id
  instance_type = "t2.micro"
  security_groups = [aws_security_group.security_group.id]
  key_name = aws_key_pair.key_pair.id
  subnet_id = aws_subnet.private[each.value].id
  source_dest_check = false
  tags = {
    Name = "${var.vpc_name}-instance_private-${each.value}"
  }
}

### Step 10: Creation d'une adresse ip reservée
resource "aws_eip" "addr_eip" {
  for_each = toset(var.vpc_azs)  
  vpc = true
  
}

### Step 11: Creation des assocations entre l'adresse ip réservée et l'instance
resource "aws_eip_association" "eip_assoc" {
  for_each = toset(var.vpc_azs)
  instance_id   = aws_instance.instance[each.value].id
  allocation_id = aws_eip.addr_eip[each.value].id
}


### Step 12:  Creation des tables de routages (publics)
resource "aws_route_table" "route_table_public" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "${var.vpc_name}-public"
  }
}

### Step 12.1:  Creation des tables de routages (privates)
resource "aws_route_table" "route_table_private" {
  for_each = toset(var.vpc_azs)
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.vpc_name}-private-${var.aws_region}${each.value}"
  }
}

### Step 13: Creation d'une route (public)
### gateway / instance_id : Indique par quel moyen on doit sortir pour acceder à internet (0.0.0.0/0)
resource "aws_route" "route_public" {

  route_table_id            = aws_route_table.route_table_public.id
  destination_cidr_block    = "0.0.0.0/0"
  gateway_id                = aws_internet_gateway.gateway.id 
}

### Step 13.1: Creation d'une route (private)
resource "aws_route" "route_private" {
  for_each = toset(var.vpc_azs)
  route_table_id = aws_route_table.route_table_private[each.value].id
  destination_cidr_block = "0.0.0.0/0"
  instance_id = aws_instance.instance[each.value].id
}

### Step 14: Creation des associations (public)

resource "aws_route_table_association" "route_table_association_public"{
  for_each = toset(var.vpc_azs)
  subnet_id = aws_subnet.public[each.value].id
  route_table_id = aws_route_table.route_table_public.id
}

### Step 14.1: Creation des associations (private)
resource "aws_route_table_association" "route_table_association_private"{
  for_each = toset(var.vpc_azs)
  subnet_id = aws_subnet.private[each.value].id
  route_table_id = aws_route_table.route_table_private[each.value].id
}


### Step 15: Creation d'un connection ssh
resource "aws_security_group_rule" "security_group_rule_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  security_group_id = aws_security_group.security_group.id
  cidr_blocks       = ["0.0.0.0/0"]
}

