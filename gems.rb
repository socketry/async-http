source 'https://rubygems.org'

gemspec

group :maintenance, optional: true do
	gem "bake-modernize"
	gem "bake-bundler"
end

# gem "async", path: "../async"
# gem "async-io", path: "../async-io"

# gem "protocol-http", path: "../protocol-http"
# gem "protocol-http1", path: "../protocol-http1"
# gem "protocol-http2", path: "../protocol-http2"
# gem "protocol-hpack", path: "../protocol-hpack"

gem "thread-local"
