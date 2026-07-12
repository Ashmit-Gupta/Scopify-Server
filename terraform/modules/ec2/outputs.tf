output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.this.id
}

output "public_ip" {
  description = "Public IP address"
  value       = aws_instance.this.public_ip
}

output "private_ip" {
  description = "Private IP address"
  value       = aws_instance.this.private_ip
}

output "public_dns" {
  description = "Public DNS name"
  value       = aws_instance.this.public_dns
}

output "private_dns" {
  description = "Private DNS name"
  value       = aws_instance.this.private_dns
}

output "availability_zone" {
  description = "Availability zone"
  value       = aws_instance.this.availability_zone
}

output "subnet_id" {
  description = "Subnet ID"
  value       = aws_instance.this.subnet_id
}

output "instance_type" {
  description = "Instance type"
  value       = aws_instance.this.instance_type
}

output "ami" {
  description = "AMI ID"
  value       = aws_instance.this.ami
}

output "name" {
  description = "Name tag value"
  value       = aws_instance.this.tags.Name
}

output "tags" {
  description = "All instance tags"
  value       = aws_instance.this.tags
}
