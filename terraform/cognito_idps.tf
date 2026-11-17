# No email or name is mapped from either IdP. Accounts are never matched on
# email, and the display name is typed at onboarding.

resource "aws_cognito_identity_provider" "apple" {
  user_pool_id  = aws_cognito_user_pool.main.id
  provider_name = "SignInWithApple"
  provider_type = "SignInWithApple"

  provider_details = {
    client_id        = var.apple_services_id
    team_id          = var.apple_team_id
    key_id           = var.apple_key_id
    private_key      = var.apple_private_key
    authorize_scopes = "name"
  }

  attribute_mapping = {
    username          = "sub"
    "custom:apple_at" = "access_token"
  }
}

# provider_type "Google", not "OIDC": social IdPs share the 10k free MAU tier,
# while OIDC federation gets 50 (RESEARCH.md §3).
resource "aws_cognito_identity_provider" "google" {
  user_pool_id  = aws_cognito_user_pool.main.id
  provider_name = "Google"
  provider_type = "Google"

  provider_details = {
    client_id        = var.google_client_id
    client_secret    = var.google_client_secret
    authorize_scopes = "openid profile"

    # Cognito fills these in on create; leaving them out gives a permanent diff
    # that a later apply would act on. Same values as today-in-sports.
    attributes_url                = "https://people.googleapis.com/v1/people/me?personFields="
    attributes_url_add_attributes = "true"
    authorize_url                 = "https://accounts.google.com/o/oauth2/v2/auth"
    oidc_issuer                   = "https://accounts.google.com"
    token_request_method          = "POST"
    token_url                     = "https://www.googleapis.com/oauth2/v4/token"
  }

  attribute_mapping = {
    username = "sub"
  }
}
