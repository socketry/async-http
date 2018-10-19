
$LOAD_PATH.unshift File.expand_path("../../lib", __dir__)

require 'async'
require 'async/http/server'
require 'async/http/url_endpoint'

protocol = Async::HTTP::Protocol::HTTP2
endpoint = Async::HTTP::URLEndpoint.parse('http://127.0.0.1:9222', reuse_port: true)

Async.logger.level = Logger::DEBUG

Async.run do
	server = Async::HTTP::Server.for(endpoint, protocol) do |request|
		Async::HTTP::Response[200, {}, request.body]
	end
	
	server.run
end
