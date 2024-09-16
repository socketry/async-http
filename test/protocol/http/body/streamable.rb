# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require "async/http/protocol/http"
require "protocol/http/body/streamable"
require "sus/fixtures/async/http"

AnEchoServer = Sus::Shared("an echo server") do
	let(:app) do
		::Protocol::HTTP::Middleware.for do |request|
			streamable = ::Protocol::HTTP::Body::Streamable.response(request) do |stream|
				Console.debug(self, "Echoing chunks...")
				while chunk = stream.readpartial(1024)
					Console.debug(self, "Reading chunk:", chunk: chunk)
					stream.write(chunk)
				end
			rescue EOFError
				Console.debug(self, "EOF.")
				# Ignore.
			ensure
				Console.debug(self, "Closing stream.")
				stream.close
			end
			
			::Protocol::HTTP::Response[200, {}, streamable]
		end
	end
	
	it "should echo the request body" do
		chunks = ["Hello,", "World!"]
		response_chunks = Queue.new
		
		output = ::Protocol::HTTP::Body::Writable.new
		response = client.post("/", body: output)
		stream = ::Protocol::HTTP::Body::Stream.new(response.body, output)
		
		begin
			Console.debug(self, "Echoing chunks...")
			chunks.each do |chunk|
				Console.debug(self, "Writing chunk:", chunk: chunk)
				stream.write(chunk)
			end
			
			Console.debug(self, "Closing write.")
			stream.close_write
			
			Console.debug(self, "Reading chunks...")
			while chunk = stream.readpartial(1024)
				Console.debug(self, "Reading chunk:", chunk: chunk)
				response_chunks << chunk
			end
		rescue EOFError
			Console.debug(self, "EOF.")
			# Ignore.
		ensure
			Console.debug(self, "Closing stream.")
			stream.close
			response_chunks.close
		end
		
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
			streamable = ::Protocol::HTTP::Body::Streamable.response(request) do |stream|
				Console.debug(self, "Echoing chunks...")
				chunks.each do |chunk|
					stream.write(chunk)
				end
				
				Console.debug(self, "Closing write.")
				stream.close_write
				
				Console.debug(self, "Reading chunks...")
				while chunk = stream.readpartial(1024)
					Console.debug(self, "Reading chunk:", chunk: chunk)
					response_chunks << chunk
				end
			rescue EOFError
				Console.debug(self, "EOF.")
				# Ignore.
			ensure
				Console.debug(self, "Closing stream.")
				stream.close
			end
			
			::Protocol::HTTP::Response[200, {}, streamable]
		end
	end
	
	it "should echo the response body" do
		output = ::Protocol::HTTP::Body::Writable.new
		response = client.post("/", body: output)
		stream = ::Protocol::HTTP::Body::Stream.new(response.body, output)
		
		begin
			Console.debug(self, "Echoing chunks...")
			while chunk = stream.readpartial(1024)
				stream.write(chunk)
			end
		rescue EOFError
			Console.debug(self, "EOF.")
			# Ignore.
		ensure
			Console.debug(self, "Closing stream.")
			stream.close
		end
		
		chunks.each do |chunk|
			expect(response_chunks.pop).to be == chunk
		end
	end
end

[Async::HTTP::Protocol::HTTP1, Async::HTTP::Protocol::HTTP2].each do |protocol|
	describe protocol, unique: protocol.name do
		include Sus::Fixtures::Async::HTTP::ServerContext
		
		let(:protocol) {subject}
		
		it_behaves_like AnEchoServer
		it_behaves_like AnEchoClient
	end
end
