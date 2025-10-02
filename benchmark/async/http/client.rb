# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "sus/fixtures/async/http"
require "sus/fixtures/benchmark"
require "net/http"
require "uri"

describe Async::HTTP::Client do
	include Sus::Fixtures::Async::HTTP::ServerContext
	include Sus::Fixtures::Benchmark
	
	let(:count) {100}
	
	RESPONSE_DATA = "x" * 1024 * 1024 * 2 # 2MB
	
	def app
		Protocol::HTTP::Middleware.for do |request|
			# sleep 0.001 # Simulate some work.
			
			Protocol::HTTP::Response[
				200,
				{
					"content-type" => "text/plain",
					"cache-control" => "no-cache, no-store",
				},
				RESPONSE_DATA
			]
		end
	end
	
	with Thread do
		measure Net::HTTP do |repeats|
			uri = URI(self.bound_url)
			repeats.times do
				threads = []
				
				count.times do
					threads << Thread.new do
						http = Net::HTTP.new(uri.host, uri.port)
						
						response = http.get("/")
						response.body.length
					ensure
						http.finish rescue nil
					end
				end
				
				threads.each(&:join)
			end
		end
	end
	
	with Async do
		measure Net::HTTP do |repeats|
			uri = URI(self.bound_url)
			repeats.times do
				tasks = []
				
				count.times do
					tasks << Async do
						http = Net::HTTP.new(uri.host, uri.port)
						
						response = http.get("/")
						
					ensure
						http.finish rescue nil
					end
				end
				
				results = tasks.map(&:wait)
			end
		end
		
		measure Async::HTTP do |repeats|
			repeats.times do
				tasks = []
				
				count.times do
					tasks << Async do
						response = client.get("/")
						body = response.read
						body.length
					end
				end
				
				results = tasks.map(&:wait)
			end
		end
	end
end
