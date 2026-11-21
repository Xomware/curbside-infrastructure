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

variable "route53_zone_name" {
  description = "Shared public zone the API hostname lives in."
  type        = string
  default     = "xomware.com"
}

variable "lambda_runtime" {
  description = "Runtime for every function and the shared layer. Matches curbside-backend's python-version."
  type        = string
  default     = "python3.12"
}

variable "cors_allow_origins" {
  description = "Browser origins allowed to call the API: the web client (I9) and its local dev server."
  type        = list(string)
  default     = ["https://curbside.xomware.com", "http://localhost:4200"]
}

# From Infisical /curbside, exported by CI as TF_VAR_<lowercase>. No defaults:
# a missing secret should fail the plan, not apply an IdP that can't sign in.

variable "apple_services_id" {
  description = "Sign in with Apple Services ID, used as the IdP client_id (APPLE_SERVICES_ID)."
  type        = string
}

variable "apple_team_id" {
  description = "Apple Developer team ID (APPLE_TEAM_ID)."
  type        = string
}

variable "apple_key_id" {
  description = "Key ID of the Sign in with Apple private key (APPLE_KEY_ID)."
  type        = string
}

variable "apple_private_key" {
  description = "Sign in with Apple .p8 contents, including the BEGIN/END lines (APPLE_PRIVATE_KEY)."
  type        = string
  sensitive   = true
}

variable "google_client_id" {
  description = "Google OAuth web client ID (GOOGLE_CLIENT_ID)."
  type        = string
}

variable "google_client_secret" {
  description = "Google OAuth web client secret (GOOGLE_CLIENT_SECRET)."
  type        = string
  sensitive   = true
}

variable "anthropic_api_key" {
  description = "Anthropic API key for capture_parse (ANTHROPIC_API_KEY)."
  type        = string
  sensitive   = true
}

# APNs token auth for push_send. Placeholders let the stack apply before the key
# exists; push_send treats "unset" as unconfigured and skips sending. Real
# values come from Infisical /curbside like the rest.

variable "apns_key_id" {
  description = "APNs auth key ID (APNS_KEY_ID)."
  type        = string
  default     = "unset"
}

variable "apns_team_id" {
  description = "Apple Developer team ID, the APNs token issuer (APNS_TEAM_ID)."
  type        = string
  default     = "unset"
}

variable "apns_private_key" {
  description = "APNs .p8 contents, including the BEGIN/END lines (APNS_PRIVATE_KEY)."
  type        = string
  sensitive   = true
  default     = "unset"
}
