lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'exception_transformer/version'

Gem::Specification.new do |spec|
  spec.name          = 'exception_transformer'
  spec.version       = ExceptionTransformer::VERSION
  spec.authors       = ['Patrick McLaren', 'Allina Dolor']
  spec.email         = ['patrick@privy.com', 'allina@privy.com']

  spec.summary       = 'Error Handling'
  spec.description   = 'Transform exceptions and send to a crash reporter.'
  spec.files         =  Dir.glob('{lib,spec}/**/*')
  spec.homepage      = 'https://github.com/Privy/exception_transformer'
  spec.license       = 'MIT'

  spec.add_development_dependency 'bundler', '~> 1.17'
  spec.add_development_dependency 'rake', '>= 12.3.3'
  spec.add_development_dependency 'rspec', '~> 3.0'

  spec.add_dependency 'activesupport', '>= 5.0', '< 7'
end
