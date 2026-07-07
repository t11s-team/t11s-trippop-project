output "vpc_id" {
  description = "On-Prem simulation VPC ID."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "On-Prem simulation VPC CIDR."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "On-Prem public subnet IDs."
  value       = { for key, subnet in aws_subnet.public : key => subnet.id }
}

output "private_db_subnet_ids" {
  description = "On-Prem private DB subnet IDs."
  value       = { for key, subnet in aws_subnet.private_db : key => subnet.id }
}

output "route_table_ids" {
  description = "Route table IDs that need On-Prem -> Cloud peering route."
  value = merge(
    {
      public = aws_route_table.public.id
    },
    length(aws_route_table.private_db) > 0 ? {
      private_db = aws_route_table.private_db[0].id
    } : {}
  )
}

output "admin_security_group_id" {
  description = "Admin EC2 security group ID."
  value       = aws_security_group.admin.id
}

output "db_interface_endpoint_ids" {
  description = "Interface VPC Endpoint IDs used by the private DB subnet."
  value       = { for service, endpoint in aws_vpc_endpoint.db_interface : service => endpoint.id }
}

output "db_s3_endpoint_id" {
  description = "S3 Gateway VPC Endpoint ID used by the private DB subnet. Null when disabled."
  value       = local.create_db_endpoints ? aws_vpc_endpoint.db_s3[0].id : null
}

output "security_group_ids" {
  description = "On-Prem VPC security group IDs keyed by role."
  value = {
    admin = aws_security_group.admin.id
  }
}
