module Api
    class UsersController < ::ApplicationController
        respond_to :json
        before_action :check_authorization, only: [:update, :destroy]


        before_action :doorkeeper_authorize!


        # deal with live reload   filter
        @@elastic ||= Elastic.new(User)


        def index
            query = @@elastic.query(params)
            results = @@elastic.search(query)
            respond_with results, User::PUBLIC_DATA
        end

        def show
            user = User.find(id)

            # We only want to provide limited 'public' information
            respond_with user, User::PUBLIC_DATA
        end

        def current
            respond_with current_user
        end


        ##
        # Requests requiring authorization have already loaded the model
        def update
            @user.update_attributes(safe_params)
            respond_with @user.save
        end

        def destroy
            respond_with @user.delete
        end


        protected


        def safe_params
            params.require(:user).permit(:name, :email, :nickname)
        end

        def check_authorization
            # Find will raise a 404 (not found) if there is an error
            @user = User.find(id)
            user = current_user

            # Does the current user have permission to perform the current action
            head(:forbidden) unless @user.id == user.id || user.sys_admin
        end
    end
end
