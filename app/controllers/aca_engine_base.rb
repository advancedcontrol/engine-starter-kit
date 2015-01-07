
class AcaEngineBase < ::Orchestrator::Base
    before_action :doorkeeper_authorize!, except: :options

    # Checking if the user is an administrator
    def check_admin
        user = current_user
        user && user.sys_admin
    end

    # Checking if the user is support personnel
    def check_support
        user = current_user
        user && user.support
    end

    # current user using doorkeeper
    def current_user
        @current_user ||= User.find(doorkeeper_token.resource_owner_id) if doorkeeper_token
    end
end
