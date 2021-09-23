output "vpc_id" {
    value = aws_vpc.vpc.id
}

output "private_subnet" {
    value = [ for subnet in aws_subnet.private: subnet.id ]
}

output "public_subnet"{
    value = [for subnet in aws_subnet.public: subnet.id ]
}

output "internet_gateway" {
    value =  aws_internet_gateway.gateway.id
}

output "route_public"{
    value = aws_route.route_public
}