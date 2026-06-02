module Auth
  class API < Grape::API
    format :json

    rescue_from ArgumentError do |e|
      error!({ error: e.message }, 400)
    end

    rescue_from ActiveRecord::RecordNotUnique do |e|
      error!({ error: e.message }, 409)
    end

    desc "Login or register by name, returns access token"
    params do
      requires :name, type: String, desc: "User display name"
    end
    post "auth/login" do
      result = Auth::Services::LoginService.call(params[:name])
      result
    end
  end
end
