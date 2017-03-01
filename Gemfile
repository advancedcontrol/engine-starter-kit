source 'https://rubygems.org'

gem 'uv-rays', '1.3.8'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 4.2.7.1'
gem 'responders', '~> 2.0'  # for responds_with with rails 4.2
gem 'spider-gazelle', '2.0.4' # web server

# Database
if RUBY_PLATFORM == 'java'
    gem 'couchbase-jruby-model', git: 'https://github.com/stakach/couchbase-jruby-model.git'
    gem 'jruby-pageant' # (required by puma?)
else
    gem 'couchbase'
    gem 'couchbase-model', git: 'https://github.com/stakach/couchbase-ruby-model'
end

gem 'couchbase-id'      # Generates our model ids
gem 'elasticsearch'     # Searchable access to model indexes
gem 'co-elastic-query', '~> 2.0'


#gem 'orchestrator', git: 'https://cotag@bitbucket.org/aca/control.git'
gem 'orchestrator', path: '../control'
gem 'aca-device-modules', path: '../aca-device-modules'


# Authentication
gem 'doorkeeper', '2.1.4'
gem 'doorkeeper-couchbase', git: 'https://github.com/advancedcontrol/doorkeeper-couchbase.git'
gem 'coauth', path: '../coauth'

gem 'omniauth-saml', git: 'https://github.com/advancedcontrol/omniauth-saml.git'
gem 'omniauth-openid', git: 'https://github.com/advancedcontrol/omniauth-openid.git'
gem 'nokogiri'


gem 'omniauth-google-oauth2'

# bundle exec rake doc:rails generates the API under doc/api.
gem 'sdoc', '~> 0.4.0', group: :doc


group :development, :test do
  # Access an IRB console on exception pages or by using <%= console %> in views
  gem 'web-console', '~> 2.0'
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]

# Used for local authentication
gem 'scrypt'

# Rubinius support
#platforms :rbx do
#    gem 'rubysl'    # Standard library
#    gem 'racc'      # Parser generator
#end

gem 'websocket-driver', '0.6.3'
