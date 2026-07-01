# frozen_string_literal: true

Rails.application.routes.draw do
  root "map#index"

  get "map/reports", to: "map#reports", defaults: { format: :json }

  get "reports/lookup", to: "reports#lookup", as: :report_lookup

  resources :reports, only: %i[show] do
    collection do
      get :descriptions
    end

    resources :report_deletion_requests, only: [:create]
  end
  resources :report_photos, only: [:show]

  resources :favorites, only: [:index]
  post "favorites/:report_id", to: "favorites#create", as: :favorite_report
  delete "favorites/:report_id", to: "favorites#destroy"

  get "login", to: "sessions#new"
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy"

  get "register", to: "registrations#new"
  post "register", to: "registrations#create"

  namespace :admin do
    resources :registration_tokens, only: %i[index create destroy]
    resources :scientists, only: %i[index destroy]
    resources :report_deletion_requests, only: %i[index] do
      member do
        patch :approve
        patch :reject
      end
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
