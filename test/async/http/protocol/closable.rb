# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require "async/http/protocol/http"
require "protocol/http/body/streamable"
require "sus/fixtures/async/http"

AnEchoServer = Sus::Shared("an echo server") do
	let(:app) do
		::Protocol::HTTP::Middleware.for do |request|
			body = ::Protocol::HTTP::Body::Streamable.response(request) do |stream|
				# $stderr.puts "Server stream: #{stream.inspect}"
				
				while chunk = stream.readpartial(1024)
					# $stderr.puts "Server reading chunk: #{chunk.inspect}"
					stream.write(chunk)
				end
			rescue EOFError
				# Ignore.
			ensure
				# $stderr.puts "Server closing stream."
				stream.close
			end
			
			::Protocol::HTTP::Response[200, {}, body]
		end
	end
	
	it "should echo the request body" do
		chunks = ["Hello,", "World!"]
		response_chunks = Queue.new
		
		body = ::Protocol::HTTP::Body::Streamable.request do |stream|
			# $stderr.puts "Client stream: #{stream.inspect}"
			
			chunks.each do |chunk|
				# $stderr.puts "Client writing chunk: #{chunk.inspect}"
				stream.write(chunk)
			end
			
			# $stderr.puts "Client closing write."
			stream.close_write
			
			# $stderr.puts "Client reading chunks..."
			while chunk = stream.readpartial(1024)
				# $stderr.puts "Client reading chunk: #{chunk.inspect}"
				response_chunks << chunk
			end
		rescue EOFError
			# Ignore.
		ensure
			# $stderr.puts "Client closing stream."
			stream.close
			response_chunks.close
		end
		
		response = client.post("/", body: body)
		body.stream(response.body)
		
		chunks.each do |chunk|
			expect(response_chunks.pop).to be == chunk
		end
	end
end

AnEchoClient = Sus::Shared("an echo client") do
	let(:chunks) {["Hello,", "World!"]}
	let(:response_chunks) {Queue.new}
	
	let(:app) do
		::Protocol::HTTP::Middleware.for do |request|
			body = ::Protocol::HTTP::Body::Streamable.response(request) do |stream|
				chunks.each do |chunk|
					stream.write(chunk)
				end
				
				stream.close_write
				
				while chunk = stream.readpartial(1024)
					response_chunks << chunk
				end
			rescue EOFError
				# Ignore.
			ensure
				# $stderr.puts "Server closing stream."
				stream.close
			end
			
			::Protocol::HTTP::Response[200, {}, body]
		end
	end
	
	it "should echo the response body" do
		body = ::Protocol::HTTP::Body::Streamable.request do |stream|
			while chunk = stream.readpartial(1024)
				stream.write(chunk)
			end
		rescue EOFError
			# Ignore.
		ensure
			stream.close
		end
		
		response = client.post("/", body: body)
		body.stream(response.body)
		
		chunks.each do |chunk|
			expect(response_chunks.pop).to be == chunk
		end
	end
end

[Async::HTTP::Protocol::HTTP1].each do |protocol|
	describe protocol do
		include Sus::Fixtures::Async::HTTP::ServerContext
		
		let(:protocol) {subject}
		
		it_behaves_like AnEchoServer
		# it_behaves_like AnEchoClient
	end
end
