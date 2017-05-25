# coding: utf-8
require_relative 'lib/async/http/version'

Gem::Specification.new do |spec|
  spec.name          = "async-http"
  spec.version       = Async::HTTP::VERSION
  spec.authors       = ["Samuel Williams"]
  spec.email         = ["samuel.williams@oriontransfer.co.nz"]

  spec.summary       = ""
  spec.homepage      = "https://github.com/socketry/async-http"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency("async-io", "~> 0.1")
	
	spec.add_development_dependency "async-rspec", "~> 1.0"
	
	spec.add_development_dependency "bundler", "~> 1.3"
	spec.add_development_dependency "rspec", "~> 3.6"
	spec.add_development_dependency "rake"
end
