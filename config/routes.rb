Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
  
  # Custom health check with more details
  get "health" => "health#show"

  # API routes
  namespace :api do
    namespace :v1 do
      # Auth
      get 'me', to: 'me#show'
      
      # Admin routes (require admin authentication)
      namespace :admin do
        # Dashboard
        get 'dashboard/stats', to: 'dashboard#stats'
        
        # Orders (admin management)
        resources :orders, only: [:index, :show, :update]
        
        # Site Settings (singleton resource)
        resource :site_settings, only: [:show, :update]
        resource :settings, only: [:show, :update] # New settings endpoint
        
        # Imports
        resources :imports, only: [:index, :show, :create]
        
        # File uploads
        resources :uploads, only: [:create, :destroy]
        
        # Collections
        resources :collections, except: [:new, :edit]
        
        # Products
        resources :products, except: [:new, :edit] do
          member do
            post :duplicate
            post :archive
            post :unarchive
          end
          
          # Nested variants
          resources :variants, controller: 'product_variants', except: [:new, :edit] do
            member do
              post :adjust_stock
            end
            collection do
              post :generate
            end
          end
          
          # Nested images
          resources :images, controller: 'product_images', except: [:new, :edit] do
            member do
              post :set_primary
            end
            collection do
              post :reorder
            end
          end
        end
      end
      
      # Public routes (no authentication required)
      resources :products, only: [:index, :show]
      resources :collections, only: [:index, :show]
      
      # Cart routes (authentication optional - supports guest carts)
      get 'cart', to: 'cart#show'
      delete 'cart', to: 'cart#clear'
      post 'cart/validate', to: 'cart#validate'
      post 'cart/items', to: 'cart#add_item'
      put 'cart/items/:id', to: 'cart#update_item'
      delete 'cart/items/:id', to: 'cart#destroy_item'
      
      # Shipping routes (authentication optional)
      post 'shipping/rates', to: 'shipping#calculate_rates'
      post 'shipping/validate_address', to: 'shipping#validate_address'
      
      # Config endpoint (public)
      get 'config', to: 'config#show'
      
      # Orders
      resources :orders, only: [:create, :show, :index, :update]
    end
  end
  
  # Admin routes
  namespace :admin do
    # Admin product management will go here
    # resources :products
  end
  
  # Webhooks
  namespace :webhooks do
    # Stripe webhook
    # post 'stripe', to: 'stripe#create'
    
    # EasyPost webhook
    # post 'easypost', to: 'easypost#create'
  end

  # Defines the root path route ("/")
  root to: proc { [200, {}, ["Hafaloha API v1.0"]] }
end
