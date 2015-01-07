
# Open ID
require 'openid'
require 'open_id/store/couch_store'
require 'omniauth-openid'

# SAML
require 'omniauth-saml'


OmniAuth.config.logger = Rails.logger

Rails.application.config.middleware.use OmniAuth::Builder do

    # NOTE:: You should replace this with a valid authentication service
    provider :developer unless Rails.env.production?
end
