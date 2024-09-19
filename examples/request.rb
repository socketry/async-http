#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2024, by Samuel Williams.

require "async"
require "async/http/client"
require "async/http/endpoint"

# Console.logger.level = Logger::DEBUG

Async do |task|
	endpoint = Async::HTTP::Endpoint.parse("https://www.google.com")
	
	client = Async::HTTP::Client.new(endpoint)
	
	headers = {
		"accept" => "text/html",
	}
	
	request = Protocol::HTTP::Request.new(client.scheme, "www.google.com", "GET", "/search?q=cats", headers)
	
	puts "Sending request..."
	response = client.call(request)
	
	puts "Reading response status=#{response.status}..."
	
	if body = response.body
		while chunk = body.read
			puts chunk.size
		end
	end
	
	response.close
	
	puts "Finish reading response."
end
