require 'rspec'
require 'webmock/rspec'
require 'vcr'

# Load support files
Dir[File.join(__dir__, 'support', '**', '*.rb')].each { |f| require f }

# ---------------------------------------------------------------------------
# VCR configuration
# ---------------------------------------------------------------------------
VCR.configure do |config|
  config.cassette_library_dir = File.join(__dir__, 'cassettes')
  config.hook_into :webmock

  # Match on method + host + path only.
  # Query params (e.g. alt=json, API keys) and headers (Bearer tokens) are
  # intentionally excluded so cassettes stay key-agnostic.
  config.default_cassette_options = {
    record: :none,
    match_requests_on: %i[method host path]
  }

  # Scrub real secrets if cassettes are ever re-recorded
  config.filter_sensitive_data('<BEARER_TOKEN>') do |interaction|
    auth = interaction.request.headers['Authorization']&.first
    auth&.sub(/^Bearer /, '') unless auth.nil?
  end
  config.filter_sensitive_data('<GEMINI_KEY>') do |interaction|
    interaction.request.uri[/(?<=key=)[^&]+/]
  end
end

# ---------------------------------------------------------------------------
# WebMock — block all real HTTP; VCR will stub via WebMock for cassette tests
# ---------------------------------------------------------------------------
WebMock.disable_net_connect!(allow_localhost: true)

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Run specs in random order to surface order dependencies
  config.order = :random
  Kernel.srand config.seed
end

