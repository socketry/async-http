# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2017-2024, by Samuel Williams.

require "async/http/server"
require "async/http/client"
require "async/reactor"

require "async/http/endpoint"
require "protocol/http/accept_encoding"

require "sus/fixtures/async"
require "sus/fixtures/async/http"

describe Async::HTTP::Client do
	class RetryClient < Async::HTTP::Client
		def initialize(failures)
			@pool = FakePool.new
			@protocol = nil
			@retries = 3
			@scheme = "https"
			@authority = "example.com"
			@failures = failures
			@chunks = []
		end
		
		attr :chunks
		
		class FakePool
			def acquire
				Object.new
			end
			
			def release(connection)
			end
		end
		
		def make_response(request, connection, attempt)
			@chunks << request.body&.read
			
			if failure = @failures.shift
				raise failure
			end
			
			return Protocol::HTTP::Response[200, {}, ["OK"]]
		end
	end
	
	with "retries" do
		it "rewinds idempotent request bodies after ambiguous failures" do
			client = RetryClient.new([EOFError.new])
			request = Protocol::HTTP::Request["PUT", "/", {}, ["Hello"]]
			
			response = client.call(request)
			
			expect(response).to be(:success?)
			expect(client.chunks).to be == ["Hello", "Hello"]
		end
		
		it "rewinds non-idempotent request bodies after refused requests" do
			client = RetryClient.new([Protocol::HTTP::RefusedError.new("Request not processed.")])
			request = Protocol::HTTP::Request["POST", "/", {}, ["Hello"]]
			
			response = client.call(request)
			
			expect(response).to be(:success?)
			expect(client.chunks).to be == ["Hello", "Hello"]
		end
	end
	
	with "basic server" do
		include Sus::Fixtures::Async::HTTP::ServerContext
		
		it "client can get resource" do
			response = client.get("/")
			response.read
			expect(response).to be(:success?)
		end
		
		with "client" do
			with "#as_json" do
				it "generates a JSON representation" do
					expect(client.as_json).to be == {
						endpoint: client.endpoint.to_s,
						protocol: client.protocol,
						retries: client.retries,
						scheme: endpoint.scheme,
						authority: endpoint.authority,
					}
				end
				
				it "generates a JSON string" do
					expect(JSON.dump(client)).to be == client.to_json
				end
			end
		end
		
		with "server" do
			with "#as_json" do
				it "generates a JSON representation" do
					expect(server.as_json).to be == {
						endpoint: server.endpoint.to_s,
						protocol: server.protocol,
						scheme: server.scheme,
					}
				end
				
				it "generates a JSON string" do
					expect(JSON.dump(server)).to be == server.to_json
				end
			end
		end
	end
	
	with "non-existant host" do
		include Sus::Fixtures::Async::ReactorContext
		
		let(:endpoint) {Async::HTTP::Endpoint.parse("http://the.future")}
		let(:client) {Async::HTTP::Client.new(endpoint)}
		
		it "should fail to connect" do
			expect do
				client.get("/")
			end.to raise_exception(SocketError, message: be =~ /not known/)
		end
	end
end
