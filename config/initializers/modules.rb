Dir[Rails.root.join("app/modules/**/*.rb")].sort.each { |f| require f }
