# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023, by Thomas Morgan.

$LOAD_PATH.unshift File.expand_path("../../lib", __dir__)
# $:.unshift File.expand_path '../../../protocol-http1/lib', __dir__

require 'async'
require 'async/http/client'
require 'async/http/endpoint'

CONNECT_TIMEOUT       = 3
IDLE_TIMEOUT          = 90
READ_WRITE_TIMEOUT    = 5
RESPONSE_WAIT_TIMEOUT = 55

METRICS = {
	requests_sent:      0,
	responses_received: 0,
}

module HTTP1Timeouts
	
	def sending_request
		stream.io.timeout = READ_WRITE_TIMEOUT
		
		# To count after the request has been fully written, move this into waiting_for_response.
		METRICS[:requests_sent] += 1
	end
	
	def waiting_for_response
		# Upstreams sometimes take a while to process a request and begin the response.
		# This allows extra time at that stage.
		stream.io.timeout = RESPONSE_WAIT_TIMEOUT
	end
	
	def received_response
		# Return to a shorter timeout for reading the body, if any.
		stream.io.timeout = READ_WRITE_TIMEOUT
		
		METRICS[:responses_received] += 1
	end
	
end

module HTTP2Timeouts
	
	def connection_ready
		# To facilitate keepalive, use IDLE_TIMEOUT instead of READ_WRITE_TIMEOUT
		stream.io.timeout = IDLE_TIMEOUT
	end
	
end

Protocol::HTTP1::Connection.include HTTP1Timeouts
Async::HTTP::Protocol::HTTP2::Client.include HTTP2Timeouts

endpoint = Async::HTTP::Endpoint.parse('http://127.0.0.1:8080', reuse_port: true, timeout: CONNECT_TIMEOUT)


protocol = Async::HTTP::Protocol::HTTP1
# protocol = Async::HTTP::Protocol::HTTP2

puts "Making request with #{protocol}..."
Async do |task|
	client = Async::HTTP::Client.new(endpoint, protocol: protocol)
	response = client.get(endpoint.path)
	puts response.read
ensure
	client.close
end

puts METRICS
