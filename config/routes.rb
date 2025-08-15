Rails.application.routes.draw do
  resources :jira, only: [ :index ]
  resources :chat, only: [ :index ]
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Debug controller but only in development
  if Rails.env.development?
    resources :debug, only: [ :index, :create ] do
      collection do
        post :prompt
        put :update
      end
    end
  end
end
