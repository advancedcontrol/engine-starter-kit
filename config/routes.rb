Rails.application.routes.draw do
    # Scope at the same location as built in control links for consistency
    # It does use the same API controller for authentication / authorization
    namespace :api do
        get 'users/current' => 'users#current'
        resources :users
    end
    mount Orchestrator::Engine => "/control", as: "control"
end