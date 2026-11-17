variable "aws_region" {
  description = "Region for every resource in this stack."
  type        = string
  default     = "us-east-1"
}

variable "app_name" {
  description = "Resource name prefix. Effectively permanent: the pool, table and bucket can't be renamed without replacement."
  type        = string
  default     = "curbside"
}

variable "environment" {
  description = "Tag value only. There is one deployed environment."
  type        = string
  default     = "production"
}

variable "owner" {
  description = "Tag value for cost attribution."
  type        = string
  default     = "xomware"
}
