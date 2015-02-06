Rails.application.routes.draw do
    # Scope at the same location as built in control links for consistency
    # It does use the same API controller for authentication / authorization
    mount Orchestrator::Engine => "/control", as: "control"
end