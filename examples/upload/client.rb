#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2024, by Samuel Williams.
# Copyright, 2020, by Bruno Sutic.

$LOAD_PATH.unshift File.expand_path("../../lib", __dir__)

require "async"
require "protocol/http/body/file"
require "async/http/client"
require "async/http/endpoint"

class Delayed < ::Protocol::HTTP::Body::Wrapper
	def initialize(body, delay = 0.01)
		super(body)
		
		@delay = delay
	end
	
	def ready?
		false
	end
	
	def read
		sleep(@delay)
		
		return super
	end
end

Async do
	endpoint = Async::HTTP::Endpoint.parse("http://localhost:9222")
	client = Async::HTTP::Client.new(endpoint, protocol: Async::HTTP::Protocol::HTTP2)
	
	headers = [
		["accept", "text/plain"],
	]
	
	body = Delayed.new(Protocol::HTTP::Body::File.open(File.join(__dir__, "data.txt"), block_size: 32))
	
	response = client.post(endpoint.path, headers, body)
	
	puts response.status
	
	# response.read -> string
	# response.each {|chunk| ...}
	# response.close (forcefully ignore data)
	# body = response.finish (read and buffer response)
	# response.save("echo.txt")
	
	response.each do |chunk|
		puts chunk.inspect
	end
	
ensure
	client.close if client
end

puts "Done."
