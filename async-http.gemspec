# coding: utf-8
require_relative 'lib/async/http/version'

Gem::Specification.new do |spec|
	spec.name          = "async-http"
	spec.version       = Async::HTTP::VERSION
	spec.authors       = ["Samuel Williams"]
	spec.email         = ["samuel.williams@oriontransfer.co.nz"]

	spec.summary       = "A HTTP client and server library."
	spec.homepage      = "https://github.com/socketry/async-http"

	spec.files         = `git ls-files -z`.split("\x0").reject do |f|
		f.match(%r{^(test|spec|features)/})
	end
	spec.executables   = spec.files.grep(%r{^bin/}) {|f| File.basename(f)}
	spec.require_paths = ["lib"]
	
	spec.add_dependency("async", "~> 1.6")
	spec.add_dependency("async-io", "~> 1.16")
	
	spec.add_dependency("http-protocol", "~> 0.9.0")
	
	# spec.add_dependency("openssl")
	
	spec.add_development_dependency "async-rspec", "~> 1.10"
	spec.add_development_dependency "async-container", "~> 0.5.0"
	
	spec.add_development_dependency "bundler", "~> 1.3"
	spec.add_development_dependency "rspec", "~> 3.6"
	spec.add_development_dependency "rake"
end
