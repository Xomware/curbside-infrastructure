# Standalone pool, not the shared xomware_users one: this app holds data about
# third parties and must be able to live or die alone, and the shared pool's
# email auto-link is exactly what this app must not do.
resource "aws_cognito_user_pool" "main" {
  name                = "${var.app_name}-users"
  user_pool_tier      = "LITE"
  deletion_protection = "ACTIVE"

  username_configuration {
    case_sensitive = false
  }

  # Apple and Google only. Admin-only creation shuts the public SignUp API,
  # which otherwise accepts passwords on any client regardless of its IdP list.
  # Federated sign-in still creates users.
  admin_create_user_config {
    allow_admin_create_user_only = true
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "admin_only"
      priority = 1
    }
  }

  # Apple's access token, rewritten on every Apple sign-in, so me_delete can
  # call Apple's /auth/revoke (RESEARCH.md §6). Cognito can never remove or
  # alter a custom attribute once created.
  schema {
    name                     = "apple_at"
    attribute_data_type      = "String"
    mutable                  = true
    developer_only_attribute = false

    string_attribute_constraints {
      min_length = 0
      max_length = 2048
    }
  }

  lifecycle {
    prevent_destroy = true
  }
}

# A bare "curbside" prefix is likely taken; prefixes are global per region.
# Apple's and Google's consoles point at this hostname, so it must not change.
resource "aws_cognito_user_pool_domain" "main" {
  domain       = "xomware-${var.app_name}"
  user_pool_id = aws_cognito_user_pool.main.id
}

resource "aws_cognito_user_pool_client" "ios" {
  name            = "${var.app_name}-ios"
  user_pool_id    = aws_cognito_user_pool.main.id
  generate_secret = false

  supported_identity_providers = [
    aws_cognito_identity_provider.apple.provider_name,
    aws_cognito_identity_provider.google.provider_name,
  ]

  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["openid"]
  callback_urls                        = ["curbside://auth/callback"]
  explicit_auth_flows                  = ["ALLOW_REFRESH_TOKEN_AUTH"]

  # read_attributes stays unset: Cognito then exposes standard attributes only,
  # which keeps custom:apple_at out of ID tokens. Write access is what lets the
  # IdP mapping populate it.
  write_attributes = ["custom:apple_at"]

  access_token_validity  = 60
  id_token_validity      = 60
  refresh_token_validity = 30

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }

  prevent_user_existence_errors = "ENABLED"
}

# Same flow as iOS. Cognito has no switch to require PKCE on a public client,
# so the Angular app must always send an S256 code_challenge.
resource "aws_cognito_user_pool_client" "web" {
  name            = "${var.app_name}-web"
  user_pool_id    = aws_cognito_user_pool.main.id
  generate_secret = false

  supported_identity_providers = [
    aws_cognito_identity_provider.apple.provider_name,
    aws_cognito_identity_provider.google.provider_name,
  ]

  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["openid"]
  callback_urls = [
    "https://${local.web_domain_name}/auth/callback",
    "http://localhost:4200/auth/callback",
  ]
  logout_urls = [
    "https://${local.web_domain_name}",
    "http://localhost:4200",
  ]
  explicit_auth_flows = ["ALLOW_REFRESH_TOKEN_AUTH"]

  # As on iOS: write lets the Apple mapping refresh custom:apple_at on a web
  # sign-in, unset reads keep it out of ID tokens.
  write_attributes = ["custom:apple_at"]

  access_token_validity  = 60
  id_token_validity      = 60
  refresh_token_validity = 30

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }

  prevent_user_existence_errors = "ENABLED"
}
