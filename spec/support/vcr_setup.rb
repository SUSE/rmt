require 'vcr'

VCR.configure do |c|
  c.cassette_library_dir = 'spec/fixtures/vcr_cassettes'
  c.hook_into :typhoeus
  c.allow_http_connections_when_no_cassette = true
  c.configure_rspec_metadata!
end
