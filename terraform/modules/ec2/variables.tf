variable "name" {
  type        = string
  description = "Name tag for the EC2 instance"
}

variable "ami_id" {
  type        = string
  description = "AMI ID"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type"
}

variable "key_name" {
  type        = string
  description = "EC2 key pair name for SSH"
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID to launch the instance in"
}

variable "security_group_ids" {
  type        = list(string)
  description = "One or more security group IDs to attach"
}

variable "associate_public_ip_address" {
  type        = bool
  description = "Whether to assign a public IP"
  default     = true
}

variable "iam_instance_profile" {
  type        = string
  description = "IAM instance profile name for SSM (and other AWS APIs)"
  default     = null
}

variable "user_data_base64" {
  type        = string
  description = "Optional cloud-init / user data (base64)"
  default     = null
}

variable "user_data_replace_on_change" {
  type        = bool
  description = "Recreate instance when user_data changes"
  default     = false
}

variable "root_volume_size" {
  type        = number
  description = "Root EBS volume size in GB"
  default     = 25
}

variable "root_volume_type" {
  type        = string
  description = "Root EBS volume type"
  default     = "gp3"
}

variable "http_tokens" {
  type        = string
  description = "IMDSv2 setting — required or optional"
  default     = "required"
}

variable "http_put_response_hop_limit" {
  type        = number
  description = "IMDS hop limit"
  default     = 2
}

variable "tags" {
  type        = map(string)
  description = "Base tags applied to the instance"
  default     = {}
}

variable "instance_tags" {
  type        = map(string)
  description = "Extra instance tags (Name, Role, Ansible, etc.)"
  default     = {}
}
