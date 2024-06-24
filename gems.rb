# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2017-2024, by Samuel Williams.

source 'https://rubygems.org'

gemspec

# gem "async", path: "../async"
# gem "async-io", path: "../async-io"
# gem "io-endpoint", path: "../io-endpoint"
# gem "io-stream", path: "../io-stream"
# gem "openssl", git: "https://github.com/ruby/openssl.git"
# gem "traces", path: "../traces"
# gem "sus-fixtures-async-http", path: "../sus-fixtures-async-http"

# gem "protocol-http", path: "../protocol-http"
# gem "protocol-http1", path: "../protocol-http1"
# gem "protocol-http2", path: "../protocol-http2"
# gem "protocol-hpack", path: "../protocol-hpack"

group :maintenance, optional: true do
	gem "bake-modernize"
	gem "bake-gem"
	
	gem "falcon", "~> 0.46"
	gem "utopia-project"
end

group :test do
	gem "covered"
	gem "sus"
	gem "sus-fixtures-async"
	gem "sus-fixtures-async-http", "~> 0.8"
	gem "sus-fixtures-openssl"
	
	gem "bake"
	gem "bake-test"
	gem "bake-test-external"
	
	gem "async-container", "~> 0.14"
	gem "async-rspec", "~> 1.10"

	gem "localhost"
	gem "rack-test"
end
