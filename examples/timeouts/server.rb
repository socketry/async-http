# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023, by Thomas Morgan.

$LOAD_PATH.unshift File.expand_path("../../lib", __dir__)
# $:.unshift File.expand_path '../../../protocol-http1/lib', __dir__

require 'async'
require 'async/http/server'
require 'async/http/endpoint'

IDLE_TIMEOUT       = 90
READ_WRITE_TIMEOUT = 5

METRICS = {
	requests_received: 0,
	responses_sent:    0,
}

module HTTP1Timeouts
	
	def waiting_for_request
		if count == 0
			# First request for this connection
			stream.io.timeout = READ_WRITE_TIMEOUT
		else
			# Additional requests; aka keep-alive
			stream.io.timeout = IDLE_TIMEOUT
		end
	end
	
	def receiving_request
		# Client must send the request headers and body, if any, in a timely manner.
		stream.io.timeout = READ_WRITE_TIMEOUT
		
		METRICS[:requests_received] += 1
	end
	
	def sent_response
		# alternate location for:
		# stream.io.timeout = IDLE_TIMEOUT
		
		METRICS[:responses_sent] += 1
	end
	
end

module HTTP2Timeouts
	
	def connection_ready
		stream.io.timeout = IDLE_TIMEOUT
	end
	
end

Protocol::HTTP1::Connection.include HTTP1Timeouts
Async::HTTP::Protocol::HTTP2::Server.include HTTP2Timeouts

endpoint = Async::HTTP::Endpoint.parse('http://127.0.0.1:8080', reuse_port: true, timeout: READ_WRITE_TIMEOUT)


protocol = Async::HTTP::Protocol::HTTP1
# protocol = Async::HTTP::Protocol::HTTP2

puts "Accepting #{protocol}..."
begin
	Async do
		server = Async::HTTP::Server.for(endpoint, protocol: protocol) do |request|
			Protocol::HTTP::Response[200, {}, 'response from server']
		end
		server.run
	end
rescue Interrupt
end

puts METRICS
