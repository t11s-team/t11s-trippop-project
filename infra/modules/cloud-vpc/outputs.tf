output "vpc_id" {
  description = "Cloud VPC ID."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "Cloud VPC CIDR."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs."
  value       = { for key, subnet in aws_subnet.public : key => subnet.id }
}

output "app_subnet_ids" {
  description = "Private app subnet IDs."
  value       = { for key, subnet in aws_subnet.app : key => subnet.id }
}

output "route_table_ids" {
  description = "Route table IDs that need Cloud -> On-Prem peering route."
  value = merge(
    {
      public = aws_route_table.public.id
    },
    { for key, route_table in aws_route_table.app : "app-${key}" => route_table.id }
  )
}

output "nat_gateway_id" {
  description = "First NAT Gateway ID when enabled. Null when disabled. Use nat_gateway_ids for AZ-aware values."
  value       = try(aws_nat_gateway.this[sort(keys(aws_nat_gateway.this))[0]].id, null)
}

output "nat_gateway_ids" {
  description = "NAT Gateway IDs keyed by public subnet/AZ key when enabled."
  value       = { for key, nat_gateway in aws_nat_gateway.this : key => nat_gateway.id }
}

output "nat_eip_public_ip" {
  description = "First NAT Gateway Elastic IP public address when enabled. Null when disabled. Use nat_eip_public_ips for AZ-aware values."
  value       = try(aws_eip.nat[sort(keys(aws_eip.nat))[0]].public_ip, null)
}

output "nat_eip_public_ips" {
  description = "NAT Gateway Elastic IP public addresses keyed by public subnet/AZ key when enabled."
  value       = { for key, eip in aws_eip.nat : key => eip.public_ip }
}

output "alb_security_group_id" {
  description = "ALB security group ID."
  value       = aws_security_group.alb.id
}

output "eks_nodes_security_group_id" {
  description = "EKS worker node security group ID."
  value       = aws_security_group.eks_nodes.id
}

output "security_group_ids" {
  description = "Cloud VPC security group IDs keyed by role."
  value = {
    alb           = aws_security_group.alb.id
    eks_nodes     = aws_security_group.eks_nodes.id
    eks_endpoints = try(aws_security_group.eks_endpoints[0].id, null)
  }
}

output "eks_interface_endpoint_ids" {
  description = "Interface VPC Endpoint IDs used by private EKS nodes."
  value       = { for service, endpoint in aws_vpc_endpoint.eks_interface : service => endpoint.id }
}

output "eks_s3_endpoint_id" {
  description = "S3 Gateway VPC Endpoint ID used by private EKS nodes. Null when disabled."
  value       = try(aws_vpc_endpoint.eks_s3[0].id, null)
}
