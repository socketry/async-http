#!/usr/bin/env ruby

$LOAD_PATH.unshift File.expand_path("../../lib", __dir__)

require 'async'
require 'protocol/http/body/file'
require 'async/http/body/delayed'
require 'async/http/client'
require 'async/http/endpoint'

Async do
	endpoint = Async::HTTP::Endpoint.parse("http://localhost:9222")
	client = Async::HTTP::Client.new(endpoint, Async::HTTP::Protocol::HTTP2)
	
	headers = [
		['accept', 'text/plain'],
	]
	
	body = Async::HTTP::Body::Delayed.new(Protocol::HTTP::Body::File.open(File.join(__dir__, "data.txt"), block_size: 32))
	
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
