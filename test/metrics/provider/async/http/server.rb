# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "metrics/provider/async/http/server"
require "async/http/server"
require "async/http/endpoint"
require "async/http/client"
require "protocol/http/middleware"
require "sus/fixtures/async"

describe Async::HTTP::Server do
	include Sus::Fixtures::Async::ReactorContext
	
	let(:endpoint) {Async::HTTP::Endpoint.parse("http://localhost:0")}
	
	with "metrics provider" do
		let(:app) do
			Protocol::HTTP::Middleware.for do |request|
				Protocol::HTTP::Response[200, {}, ["Hello, World!"]]
			end
		end
		
		let(:server) {subject.new(app, endpoint)}
		
		it "emits queue time metric when x-request-start header is present" do
			# Start the server
			server_task = server.run
			bound_endpoint = server_task.wait_until_ready
			
			# Calculate a timestamp 100ms in the past (nginx format with 't=' prefix)
			request_start = Process.clock_gettime(Process::CLOCK_REALTIME) - 0.1
			
			# Expect the histogram metric to be emitted with a value around 0.1 seconds
			expect(Async::HTTP::Server::ASYNC_HTTP_SERVER_REQUEST_QUEUE_TIME).to receive(:emit) do |value, tags:|
				expect(value).to be_within(0.05).of(0.1)
				expect(tags).to be == ["method:GET"]
			end
			
			# Make a request with the x-request-start header
			client = Async::HTTP::Client.new(bound_endpoint)
			headers = [["x-request-start", "t=#{request_start}"]]
			response = client.get("/", headers)
			
			expect(response.status).to be == 200
			response.finish
			
			client.close
			server_task.stop
		end
		
		it "handles nginx-style timestamp format (t=prefix)" do
			server_task = server.run
			bound_endpoint = server_task.wait_until_ready
			
			request_start = Process.clock_gettime(Process::CLOCK_REALTIME) - 0.05
			
			expect(Async::HTTP::Server::ASYNC_HTTP_SERVER_REQUEST_QUEUE_TIME).to receive(:emit) do |value, tags:|
				expect(value).to be > 0
				expect(value).to be < 1
			end
			
			client = Async::HTTP::Client.new(bound_endpoint)
			headers = [["x-request-start", "t=#{request_start}"]]
			response = client.get("/", headers)
			
			expect(response.status).to be == 200
			response.finish
			
			client.close
			server_task.stop
		end
		
		it "handles plain Unix timestamp format" do
			server_task = server.run
			bound_endpoint = server_task.wait_until_ready
			
			request_start = Process.clock_gettime(Process::CLOCK_REALTIME) - 0.05
			
			expect(Async::HTTP::Server::ASYNC_HTTP_SERVER_REQUEST_QUEUE_TIME).to receive(:emit) do |value, tags:|
				expect(value).to be > 0
				expect(value).to be < 1
			end
			
			client = Async::HTTP::Client.new(bound_endpoint)
			headers = [["x-request-start", request_start.to_s]]
			response = client.get("/", headers)
			
			expect(response.status).to be == 200
			response.finish
			
			client.close
			server_task.stop
		end
		
		it "does not emit queue time metric when x-request-start header is missing" do
			server_task = server.run
			bound_endpoint = server_task.wait_until_ready
			
			# Should not emit the queue time metric
			expect(Async::HTTP::Server::ASYNC_HTTP_SERVER_REQUEST_QUEUE_TIME).not.to receive(:emit)
			
			client = Async::HTTP::Client.new(bound_endpoint)
			response = client.get("/")
			
			expect(response.status).to be == 200
			response.finish
			
			client.close
			server_task.stop
		end
		
		it "ignores invalid timestamp formats" do
			server_task = server.run
			bound_endpoint = server_task.wait_until_ready
			
			# Should not emit the queue time metric for invalid timestamp
			expect(Async::HTTP::Server::ASYNC_HTTP_SERVER_REQUEST_QUEUE_TIME).not.to receive(:emit)
			
			client = Async::HTTP::Client.new(bound_endpoint)
			headers = [["x-request-start", "invalid-timestamp"]]
			response = client.get("/", headers)
			
			expect(response.status).to be == 200
			response.finish
			
			client.close
			server_task.stop
		end
		
	end
end

