# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "metrics/provider/async/http/server"
require "protocol/http/middleware"
require "sus/fixtures/async/http/server_context"

describe Async::HTTP::Server do
	include Sus::Fixtures::Async::HTTP::ServerContext
	
	with "metrics provider" do
		let(:app) do
			Protocol::HTTP::Middleware.for do |request|
				Protocol::HTTP::Response[200, {}, ["Hello, World!"]]
			end
		end
		
		it "emits queue time metric when x-request-start header is present" do
			# Calculate a timestamp 100ms in the past (nginx format with 't=' prefix)
			request_start = Process.clock_gettime(Process::CLOCK_REALTIME) - 0.1
			
			# Expect the histogram metric to be emitted with a value around 0.1 seconds
			expect(Async::HTTP::Server::ASYNC_HTTP_SERVER_REQUEST_QUEUE_TIME).to receive(:emit) do |value, tags:|
				expect(value).to be_within(0.05).of(0.1)
				expect(tags).to be == ["method:GET"]
			end
			
			# Make a request with the x-request-start header
			headers = [["x-request-start", "t=#{request_start}"]]
			response = client.get("/", headers)
			
			expect(response.status).to be == 200
			response.finish
		end
		
		it "handles nginx-style timestamp format (t=prefix)" do
			request_start = Process.clock_gettime(Process::CLOCK_REALTIME) - 0.05
			
			expect(Async::HTTP::Server::ASYNC_HTTP_SERVER_REQUEST_QUEUE_TIME).to receive(:emit) do |value, tags:|
				expect(value).to be > 0
				expect(value).to be < 1
			end
			
			headers = [["x-request-start", "t=#{request_start}"]]
			response = client.get("/", headers)
			
			expect(response.status).to be == 200
			response.finish
		end
		
		it "handles plain Unix timestamp format" do
			request_start = Process.clock_gettime(Process::CLOCK_REALTIME) - 0.05
			
			expect(Async::HTTP::Server::ASYNC_HTTP_SERVER_REQUEST_QUEUE_TIME).to receive(:emit) do |value, tags:|
				expect(value).to be > 0
				expect(value).to be < 1
			end
			
			headers = [["x-request-start", request_start.to_s]]
			response = client.get("/", headers)
			
			expect(response.status).to be == 200
			response.finish
		end
		
		it "does not emit queue time metric when x-request-start header is missing" do
			# Should not emit the queue time metric
			expect(Async::HTTP::Server::ASYNC_HTTP_SERVER_REQUEST_QUEUE_TIME).not.to receive(:emit)
			
			response = client.get("/")
			
			expect(response.status).to be == 200
			response.finish
		end
		
		it "ignores invalid timestamp formats" do
			# Should not emit the queue time metric for invalid timestamp
			expect(Async::HTTP::Server::ASYNC_HTTP_SERVER_REQUEST_QUEUE_TIME).not.to receive(:emit)
			
			headers = [["x-request-start", "invalid-timestamp"]]
			response = client.get("/", headers)
			
			expect(response.status).to be == 200
			response.finish
		end
	end
end

