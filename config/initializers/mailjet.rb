# config/initializers/mailjet.rb
Mailjet.configure do |config|
  config.api_key = ENV['MAILJET_API_KEY']       
  config.secret_key = ENV['MAILJET_SECRET_KEY']
  config.default_from = 'contact@merchflow.fr'
  config.api_version = 'v3.1'
end
