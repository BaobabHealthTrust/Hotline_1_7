Rails.application.routes.draw do



  ######################### home start ############################################
  get 'home/index'
  get 'start_call' => 'home#start_call'
  post 'start_call' => 'home#start_call'
  get 'house_keeping' => 'home#house_cleaning'
  get 'admin' => 'home#admin'
  
  get 'report' => 'home#report'
  get 'patient_demographic_report' => 'home#patient_demographic_report'
  ######################### home end ############################################
  
  ######################### user start ############################################
  get '/login' => 'user#login'
  post '/login' => 'user#login'
  get '/logout' => 'user#login'
  get 'manage_user' => 'user#manage_user'
  get 'manage_clinic' => 'user#manage_clinic'
  get '/user/new'
  post '/user/create'


  ######################### user end ############################################

  ######################### patient start ############################################
  get 'patient/dashboard/:patient_id/:tab_name' => 'patient#dashboard'
  get 'patient/edit/:patient_id' => 'patient#edit'
  post 'patient/new'
  post 'patient/search_result'
  get 'patient/search_by_name'
  post 'patient/create'
  get '/patient/given_names'
  get '/patient/family_names'
  get '/patient/given_name_plus_family_name'
  get 'patient/find_by_phone'
  get 'patient/find_by_identifier'
  post 'patient/attributes_search_results'
  get 'patient/districts'
  ######################### patient end ############################################
  

  ######################### people start ############################################
  get 'demographics/:patient_id' => 'people#demographics'
  get 'demographic_modify/:field/:patient_id' => 'people#demographic_modify'
  post '/demographic_modify' => 'people#demographic_modify'
  ######################### people end ############################################

  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  # root 'welcome#index'

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end
  root 'home#index'
end
