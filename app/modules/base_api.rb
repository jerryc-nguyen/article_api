class BaseAPI < Grape::API
  format :json

  if Rails.env.development?
    use GrapeLogging::Middleware::RequestLogger, logger:, formatter: GrapeLogging::Formatters::Rails.new
  end

  rescue_from Exception do |e|
    Rails.logger.error(e.message)
    Rails.logger.info('Logging first 20 lines of backtrace')
    e.backtrace.first(20).each { |line| Rails.logger.error line }
    error!({ error: "UNCAUGHT ERROR: #{e.message}" }, 500)
  end

  rescue_from :all do |e|
    Rails.logger.error(e.message)
    Rails.logger.info('Logging first 20 lines of backtrace')
    e.backtrace.first(20).each { |line| Rails.logger.error line }
    error!({ error: "UNCAUGHT ERROR: #{e.message} (2)" }, 500)
  end
end
