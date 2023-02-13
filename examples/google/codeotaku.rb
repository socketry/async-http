#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2023, by Samuel Williams.

require "async"
require "async/clock"
require "protocol/http/middleware"
require_relative "../../lib/async/http"

URL = "https://www.codeotaku.com/index"
ENDPOINT = Async::HTTP::Endpoint.parse(URL)

Console.logger.enable(Async::IO::Stream, Console::Logger::DEBUG)

if count = ENV['COUNT']&.to_i
	terms = terms.first(count)
end

Async do |task|
	client = Async::HTTP::Client.new(ENDPOINT)
	
	client.get(ENDPOINT.path).finish
	
	duration = Async::Clock.measure do
		20.times.map do |i|
			task.async do
				response = client.get(ENDPOINT.path)
				response.read
				$stderr.write "(#{i})"
			end
		end.map(&:wait)
	end
	
	pp duration
ensure
	client.close
end
