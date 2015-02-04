source 'https://rubygems.org'


# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 4.2.0'
gem 'responders', '~> 2.0'  # for responds_with with rails 4.2
gem 'spider-gazelle'

# Database
if RUBY_PLATFORM == 'java'
    gem 'couchbase-jruby-model', git: 'https://github.com/stakach/couchbase-jruby-model.git'
    gem 'jruby-pageant' # (required by puma?)
else
    gem 'couchbase'
    gem 'couchbase-model', git: 'https://github.com/stakach/couchbase-ruby-model'
end

#gem 'orchestrator', git: 'https://cotag@bitbucket.org/aca/control.git'
gem 'orchestrator', path: '../control'
gem 'aca-device-modules', path: '../aca-device-modules'


# Authentication
gem 'doorkeeper'
gem 'doorkeeper-couchbase', git: 'https://github.com/advancedcontrol/doorkeeper-couchbase.git'
gem 'coauth', path: '../coauth'

gem 'omniauth-saml', git: 'https://github.com/advancedcontrol/omniauth-saml.git'
gem 'omniauth-openid', git: 'https://github.com/advancedcontrol/omniauth-openid.git'


# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.0'
# bundle exec rake doc:rails generates the API under doc/api.
gem 'sdoc', '~> 0.4.0', group: :doc


group :development, :test do
  # Access an IRB console on exception pages or by using <%= console %> in views
  gem 'web-console', '~> 2.0'
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]

# Rubinius support
#platforms :rbx do
#    gem 'rubysl'    # Standard library
#    gem 'racc'      # Parser generator
#end

