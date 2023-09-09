#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023, by Samuel Williams.

require 'async'
require 'async/barrier'
require 'async/semaphore'
require 'async/http/internet'

TOPICS = ["ruby", "python", "rust"]

Async do
	internet = Async::HTTP::Internet.new
	barrier = Async::Barrier.new
	semaphore = Async::Semaphore.new(2, parent: barrier)
	
	# Spawn an asynchronous task for each topic:
	TOPICS.each do |topic|
		semaphore.async do
			response = internet.get "https://www.google.com/search?q=#{topic}"
			puts "Found #{topic}: #{response.read.scan(topic).size} times."
		end
	end
	
	# Ensure we wait for all requests to complete before continuing:
	barrier.wait
ensure
	internet&.close
end
