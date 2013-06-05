Rails.application.routes.draw do
  resources :calendars, :controller => :contents, :except => [:index, :show], :path => "content"
end
