# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2017-2025, by Samuel Williams.
# Copyright, 2018, by Janko Marohnić.
# Copyright, 2023, by Thomas Morgan.
# Copyright, 2023, by Josh Huber.
# Copyright, 2024, by Anton Zhuravsky.

require "async/http/protocol/http11"
require "async/http/a_protocol"

# Custom error class to track in tests
class BodyWriteError < StandardError; end

# A custom body class that raises during enumeration.
class ErrorProneBody < ::Protocol::HTTP::Body::Readable
	def initialize(...)
		super(...)
		
		@error = nil
	end
	
	attr :error
	
	def close(error = nil)
		@error = error
		super()
	end
	
	def each
		super
		raise BodyWriteError, "error during write"
	end
end

describe Async::HTTP::Protocol::HTTP11 do
	it_behaves_like Async::HTTP::AProtocol
	
	with "#as_json" do
		include Sus::Fixtures::Async::HTTP::ServerContext
		let(:protocol) {subject}
		
		it "generates a JSON representation" do
			response = client.get("/")
			connection = response.connection
			
			expect(connection.as_json).to be =~ /Async::HTTP::Protocol::HTTP1::Client negotiated HTTP/
		ensure
			response&.close
		end
		
		it "generates a JSON string" do
			response = client.get("/")
			connection = response.connection
			
			expect(JSON.dump(connection)).to be == connection.to_json
		ensure
			response&.close
		end
	end
	
	with "server" do
		include Sus::Fixtures::Async::HTTP::ServerContext
		
		let(:protocol) {subject}
		
		with "error during body write" do
			let(:body) {ErrorProneBody.new}
			
			let(:app) do
				Protocol::HTTP::Middleware.for do |request|
					# Return a response with a body that will raise during enumeration:
					Protocol::HTTP::Response[200, {}, body]
				end
			end
			
			it "handles error in ensure block without NameError" do
				response = client.get("/")
				
				expect do
					response.read
				end.to raise_exception(EOFError)
				
				expect(body.error).to be_a(BodyWriteError)
			end
		end
		
		with "bad requests" do
			def around
				current = Console.logger.level
				Console.logger.fatal!
				
				super
			ensure
				Console.logger.level = current
			end
			
			it "should fail cleanly when path is empty" do
				response = client.get("")
				
				expect(response.status).to be == 400
			end
		end
		
		with "head request" do
			let(:app) do
				Protocol::HTTP::Middleware.for do |request|
					Protocol::HTTP::Response[200, {}, ["Hello", "World"]]
				end
			end
			
			it "doesn't reply with body" do
				5.times do
					response = client.head("/")
					
					expect(response).to be(:success?)
					expect(response.version).to be == "HTTP/1.1"
					expect(response.body).to be(:empty?)
					expect(response.reason).to be == "OK"
					
					response.read
				end
			end
		end
		
		with "raw response" do
			let(:app) do
				Protocol::HTTP::Middleware.for do |request|
					peer = request.hijack!
					
					peer.write(
						"#{request.version} 200 It worked!\r\n" +
						"connection: close\r\n" +
						"\r\n" +
						"Hello World!"
					)
					peer.close
					
					nil
				end
			end
			
			it "reads raw response" do
				response = client.get("/")
				
				expect(response.read).to be == "Hello World!"
			end
			
			it "has access to the http reason phrase" do
				response = client.head("/")
				
				expect(response.reason).to be == "It worked!"
			end
		end
		
		with "full hijack with empty response" do
			let(:body) {::Protocol::HTTP::Body::Buffered.new([], 0)}
			
			let(:app) do
				::Protocol::HTTP::Middleware.for do |request|
					peer = request.hijack!
					
					peer.write(
						"#{request.version} 200 It worked!\r\n" +
						"connection: close\r\n" +
						"\r\n" +
						"Hello World!"
					)
					peer.close
					
					::Protocol::HTTP::Response[-1, {}, body]
				end
			end
			
			it "works properly" do
				expect(body).to receive(:close)
				
				response = client.get("/")
				
				expect(response.read).to be == "Hello World!"
			end
		end
	end
end
