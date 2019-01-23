
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'exception_transformer/version'

Gem::Specification.new do |spec|
  spec.name          = 'exception_transformer'
  spec.version       = ExceptionTransformer::VERSION
  spec.authors       = ['Patrick McLaren', 'Allina Dolor']
  spec.email         = ['patrick@privy.com', 'allina@privy.com']

  spec.summary       = 'Add exceptions to be transformed'
  spec.description   = ''
  spec.homepage      = 'https://github.com/Privy/exception-transformer'
  spec.license       = 'MIT'

  spec.add_development_dependency 'bundler', '~> 1.17'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
end
