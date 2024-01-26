# frozen_string_literal: true

require_relative "lib/async/http/version"

Gem::Specification.new do |spec|
	spec.name = "async-http"
	spec.version = Async::HTTP::VERSION
	
	spec.summary = "A HTTP client and server library."
	spec.authors = ["Samuel Williams", "Brian Morearty", "Bruno Sutic", "Janko Marohnić", "Adam Daniels", "Thomas Morgan", "Cyril Roelandt", "Denis Talakevich", "Ian Ker-Seymer", "Igor Sidorov", "Marco Concetto Rudilosso", "Olle Jonsson", "Orgad Shaneh", "Sam Shadwell", "Stefan Wrobel", "Tim Meusel", "Trevor Turk", "Viacheslav Koval"]
	spec.license = "MIT"
	
	spec.cert_chain  = ['release.cert']
	spec.signing_key = File.expand_path('~/.gem/release.pem')
	
	spec.homepage = "https://github.com/socketry/async-http"
	
	spec.files = Dir.glob(['{bake,lib}/**/*', '*.md'], File::FNM_DOTMATCH, base: __dir__)
	
	spec.required_ruby_version = ">= 3.0"
	
	spec.add_dependency "async", ">= 1.25"
	spec.add_dependency "async-io", ">= 1.28"
	spec.add_dependency "async-pool", ">= 0.2"
	spec.add_dependency "base64"
	spec.add_dependency "protocol-http", "~> 0.25.0"
	spec.add_dependency "protocol-http1", "~> 0.17.0"
	spec.add_dependency "protocol-http2", "~> 0.15.0"
	spec.add_dependency "traces", ">= 0.10.0"
end
