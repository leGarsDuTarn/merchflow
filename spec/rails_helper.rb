# This file is copied to spec/ when you run 'rails generate rspec:install'
require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?
# Uncomment the line below in case you have `--require rails_helper` in the `.rspec` file
# that will avoid rails generators crashing because migrations haven't been run yet
# return unless Rails.env.test?
require 'rspec/rails'
require 'pundit/matchers'
# Add additional requires below this line. Rails is not loaded until this point!

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
#
# The following line is provided for convenience purposes. It has the downside
# of increasing the boot-up time by auto-requiring all files in the support
# directory. Alternatively, in the individual `*_spec.rb` files, manually
# require only the support files necessary.
#
# Rails.root.glob('spec/support/**/*.rb').sort_by(&:to_s).each { |f| require f }

# Ensures that the test database schema matches the current schema file.
# If there are pending migrations it will invoke `db:test:prepare` to
# recreate the test database by loading the schema.
# If you are not using ActiveRecord, you can remove these lines.
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end
RSpec.configure do |config|
  # Permet de lier la gem Pundit aux tests de Policy
  config.include Pundit::Matchers, type: :policy

  # Permet d'utiliser 'sign_in' dans les request specs ET les system specs
  config.include Devise::Test::IntegrationHelpers, type: :request
  config.include Devise::Test::IntegrationHelpers, type: :system # INDISPENSABLE POUR LE DASHBOARD

  config.before(:each) do
    Agency.find_or_create_by!(code: 'actiale', label: 'Actiale')
  end

  config.fixture_paths = [
    Rails.root.join('spec/fixtures')
  ]

  # Setup FactoryBot
  config.include FactoryBot::Syntax::Methods

  config.use_transactional_fixtures = true

  # === LE FIX POUR TES TESTS ORANGE ===
  # Cette ligne permet à RSpec de savoir que le dossier spec/system = tests système
  config.infer_spec_type_from_file_location!

  # Configuration du driver pour les tests système
  config.before(:each, type: :system) do
    driven_by :rack_test
  end

  # Configuration spécifique quand on utilise 'js: true' (Selenium Chrome)
  config.before(:each, type: :system, js: true) do
    driven_by :selenium_chrome_headless
  end
  # =====================================

  config.filter_rails_from_backtrace!
end

# Setup ShouldaMatcher
Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
