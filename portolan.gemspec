# frozen_string_literal: true

require_relative 'lib/portolan/version'

Gem::Specification.new do |spec|
  spec.name = 'portolan'
  spec.version = Portolan::VERSION
  spec.authors = ['David Busse']
  spec.email = ['david@busse.net']

  spec.summary = 'Declared, read-only datasets that reporting code and LLMs can query safely.'
  spec.description = 'Portolan lets a Rails app chart the datasets it is willing to expose: their dimensions, ' \
                     'measures and worked examples. A dashboard or an LLM tool sends a structured request ' \
                     'and gets back only what the app has declared, never SQL.'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.3'

  spec.files = Dir['lib/**/*.rb', 'LICENSE.txt', 'README.md']
  spec.require_paths = ['lib']

  spec.add_dependency 'activesupport', '>= 7.1', '< 9'
  spec.metadata['rubygems_mfa_required'] = 'true'
end
