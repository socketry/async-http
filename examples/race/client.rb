#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2021-2024, by Samuel Williams.

require 'async'
require_relative '../../lib/async/http/internet'

Console.logger.fatal!

Async do |task|
	internet = Async::HTTP::Internet.new
	tasks = []
	
	100.times do
		tasks << task.async {
			loop do
				response = internet.get('http://127.0.0.1:8080/something/special')
				r = response.body.join
				if r.include?('nothing')
					p ['something', r]
				end
			end
		}
	end
	
	100.times do
		tasks << task.async {
			loop do
				response = internet.get('http://127.0.0.1:8080/nothing/to/worry')
				r = response.body.join
				if r.include?('something')
					p ['nothing', r]
				end
			end
		}
	end
	
	tasks.each do |t|
		sleep 0.1
		t.stop
	end
end
