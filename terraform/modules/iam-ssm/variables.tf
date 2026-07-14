variable "name" {
  type        = string
  description = "Name prefix for IAM role/profile"
}

variable "extra_policy_arns" {
  type        = list(string)
  description = "Optional extra managed policy ARNs to attach"
  default     = []
}

variable "tags" {
  type        = map(string)
  default     = {}
}
