output "db_instance_id" {
  description = "ID of the database EC2 instance"
  value       = aws_instance.db.id
}

output "db_private_ip" {
  description = "Private IP address of the database EC2"
  value       = aws_instance.db.private_ip
}

output "db_security_group_id" {
  description = "Security Group ID assigned to the database instance"
  value       = aws_security_group.db_sg.id
}

output "db_data_volume_id" {
  description = "ID of the external EBS volume for database storage"
  value       = aws_ebs_volume.db_data.id
}

output "db_name" {
  description = "The name of the initialized application database"
  value       = var.db_name
}

output "db_app_user" {
  description = "The application username for DB connection"
  value       = var.db_app_user
}
