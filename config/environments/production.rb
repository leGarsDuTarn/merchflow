require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Stockage des fichiers (Images)
  config.active_storage.service = :local
  config.active_storage.variant_processor = nil

  config.force_ssl = true

  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")
  config.silence_healthcheck_path = "/up"
  config.active_support.report_deprecations = false

  # ==============================================================================
  # FORCE L'ENVOI IMMÉDIAT (SANS FILE D'ATTENTE)
  # ==============================================================================
  config.active_job.queue_adapter = :inline

  # ==============================================================================
  # CONFIGURATION URL PRODUCTION (OFFICIEL MERCHFLOW)
  # ==============================================================================
  config.action_mailer.default_url_options = {
    host: "www.merchflow.fr",
    protocol: "https"
  }

  config.after_initialize do
    Rails.application.routes.default_url_options = {
      host: "www.merchflow.fr",
      protocol: "https"
    }
  end

  # ==============================================================================
  # CONFIGURATION MAILJET SMTP
  # ==============================================================================
  config.action_mailer.perform_caching = false
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.delivery_method = :smtp

  config.action_mailer.smtp_settings = {
    address:              'in-v3.mailjet.com',
    port:                 587,
    domain:               'merchflow.fr',
    user_name:            ENV['MAILJET_API_KEY'],
    password:             ENV['MAILJET_SECRET_KEY'],
    authentication:       'plain',
    enable_starttls_auto: true
  }

  config.i18n.fallbacks = true
  config.active_record.dump_schema_after_migration = false
  config.active_record.attributes_for_inspect = [ :id ]
end
