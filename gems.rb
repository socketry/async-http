# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2017-2023, by Samuel Williams.

source 'https://rubygems.org'

gemspec

# gem "async", path: "../async"
# gem "async-io", path: "../async-io"
# gem "traces", path: "../traces"

# gem "protocol-http", path: "../protocol-http"
gem "protocol-http1", path: "../protocol-http1"
# gem "protocol-http2", path: "../protocol-http2"
# gem "protocol-hpack", path: "../protocol-hpack"

group :maintenance, optional: true do
	gem "bake-modernize"
	gem "bake-gem"
	
	gem "bake-github-pages"
	gem "utopia-project"
end

group :test do
	gem "covered"
	gem "sus"
	gem "sus-fixtures-async"
	gem "sus-fixtures-async-http", "~> 0.7"
	gem "sus-fixtures-openssl"
	
	gem "bake"
	gem "bake-test"
	gem "bake-test-external"
	
	gem "async-container", "~> 0.14"
	gem "async-rspec", "~> 1.10"

	gem "localhost"
	gem "rack-test"
	
	# Optional dependency:
	gem "thread-local"
end
