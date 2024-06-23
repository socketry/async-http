#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require "net/http"
require "async"
require "async/http/internet"
require "async/barrier"
require "async/semaphore"

N_TIMES = 1000

Async do |task|
	internet = Async::HTTP::Internet.new
	barrier = Async::Barrier.new
	
	results = N_TIMES.times.map do |i|
		barrier.async do
			puts "Run #{i}"
			
			begin
				response = internet.get("https://httpbin.org/delay/0.5")
			ensure
				response&.finish
			end
		end
	end
	
	barrier.wait
end
