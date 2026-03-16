# frozen_string_literal: true

require_relative 'lib/legion/extensions/planning/version'

Gem::Specification.new do |spec|
  spec.name          = 'lex-planning'
  spec.version       = Legion::Extensions::Planning::VERSION
  spec.authors       = ['Matthew Iverson']
  spec.email         = ['matt@legionIO.com']
  spec.summary       = 'Hierarchical goal decomposition and plan formation for LegionIO cognitive agents'
  spec.description   = 'Models the prefrontal cortex planning function: plan trees, progress tracking, contingencies, re-planning'
  spec.homepage      = 'https://github.com/LegionIO/lex-planning'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.4'

  spec.files = Dir['lib/**/*']
  spec.require_paths = ['lib']

  spec.metadata['rubygems_mfa_required'] = 'true'
  spec.add_development_dependency 'legion-gaia'
end
