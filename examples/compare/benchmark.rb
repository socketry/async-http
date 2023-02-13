#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2023, by Samuel Williams.

require 'benchmark'

require 'httpx'

require 'async'
require 'async/barrier'
require 'async/semaphore'
require 'async/http/internet'

URL = "https://www.codeotaku.com/index"
REPEATS = 10

Benchmark.bmbm do |x|
	x.report("async-http") do
		Async do
			internet = Async::HTTP::Internet.new
			
			i = 0
			while i < REPEATS
				response = internet.get(URL)
				response.read
				
				i += 1
			end
		ensure
			internet&.close
		end
	end
	
	x.report("async-http (pipelined)") do
		Async do |task|
			internet = Async::HTTP::Internet.new
			semaphore = Async::Semaphore.new(100, parent: task)
			barrier = Async::Barrier.new(parent: semaphore)
			
			# Warm up the connection pool...
			response = internet.get(URL)
			response.read
			
			i = 0
			while i < REPEATS
				barrier.async do
					response = internet.get(URL)
					
					response.read
				end
				
				i += 1
			end
			
			barrier.wait
		ensure
			internet&.close
		end
	end
	
	x.report("httpx") do
		i = 0
		while i < REPEATS
			response = HTTPX.get(URL)
			
			response.read
			
			i += 1
		end
	end
	
	x.report("httpx (pipelined)") do
		urls = [URL] * REPEATS
		responses = HTTPX.get(*urls)
		
		responses.each do |response|
			response.read
		end
	end
end
