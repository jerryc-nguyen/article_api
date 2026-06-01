module API
  class BaseAPI < Grape::API
    format :json
    prefix :api

    rescue_from :all do |e|
      error!({ error: e.message }, 500)
    end

    mount API::Articles
  end
end
