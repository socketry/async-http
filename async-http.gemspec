
require_relative 'lib/async/http/version'

Gem::Specification.new do |spec|
	spec.name          = "async-http"
	spec.version       = Async::HTTP::VERSION
	spec.licenses      = ["MIT"]
	spec.authors       = ["Samuel Williams"]
	spec.email         = ["samuel.williams@oriontransfer.co.nz"]

	spec.summary       = "A HTTP client and server library."
	spec.homepage      = "https://github.com/socketry/async-http"

	spec.files         = `git ls-files -z`.split("\x0").reject do |f|
		f.match(%r{^(test|spec|features)/})
	end
	spec.executables   = spec.files.grep(%r{^bin/}) {|f| File.basename(f)}
	spec.require_paths = ["lib"]
	
	spec.add_dependency("async", "~> 1.23")
	spec.add_dependency("async-io", "~> 1.28")
	spec.add_dependency("async-pool", "~> 0.2")
	
	spec.add_dependency("protocol-http", "~> 0.17.0")
	spec.add_dependency("protocol-http1", "~> 0.11.0")
	spec.add_dependency("protocol-http2", "~> 0.13.0")
	
	# spec.add_dependency("openssl")
	
	spec.add_development_dependency "async-rspec", "~> 1.10"
	spec.add_development_dependency "async-container", "~> 0.14.0"
	
	spec.add_development_dependency "rack-test"
	
	spec.add_development_dependency "covered"
	spec.add_development_dependency "bundler"
	spec.add_development_dependency "bake-bundler"
	spec.add_development_dependency "rspec", "~> 3.6"
end
