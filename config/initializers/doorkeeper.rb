require 'set'

trustedClients = Set.new(['Cotag', 'AcaEngine'])

Doorkeeper.configure do
    require 'doorkeeper/orm/couchbase'
    orm :couchbase


    
    # This block will be called to check whether the
    # resource owner is authenticated or not
    resource_owner_authenticator do |routes|
        # We use cookies signed instead of session as then we can limit
        # the cookie to particular paths (i.e. /auth)
        cookie = cookies.encrypted[:user]
        user = User.find_by_id(cookie['id']) if cookie
        user || redirect_to('/login_required.html')
    end

    # restrict the access to the web interface for adding
    # oauth authorized applications
    if Rails.env.production?
        admin_authenticator do |routes|
            admin = begin
                user = User.find(cookies.encrypted[:user][:id])
                user.sys_admin == true
            rescue
                false
            end
            render nothing: true, status: :not_found unless admin
        end
    else
        admin_authenticator do |routes|
            true
        end
    end

    # Skip authorization only if the app is owned by us
    skip_authorization do |resource_owner, client|
        # NOTE:: Is the URL located on our servers?
        client.redirect_uri =~ /^http(s)?:\/\/(.+\.)?cotag\.me\/oauth-resp.html$/i || client.application.skip_authorization
    end

    # username and password authentication for local auth
    resource_owner_from_credentials do |routes|
        user_id = User.bucket.get("useremail-#{User.process_email(params[:authority], params[:username])}", {quiet: true})
        if user_id
            user = User.find(user_id)
            if user && user.authenticate(params[:password])
                user
            end
        end
    end

    # Access token expiration time (default 2 hours)
    # access_token_expires_in 2.hours
    access_token_expires_in 2.hours

    # Issue access tokens with refresh token (disabled by default)
    use_refresh_token

    # Define access token scopes for your provider
    # For more information go to https://github.com/applicake/doorkeeper/wiki/Using-Scopes
    default_scopes  :public
    optional_scopes :admin

    force_ssl_in_redirect_uri false

    grant_flows %w(authorization_code client_credentials implicit password)
end
