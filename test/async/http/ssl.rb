# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2026, by Samuel Williams.

require "async/http/server"
require "async/http/client"
require "async/http/endpoint"

require "sus/fixtures/async"
require "sus/fixtures/openssl"
require "sus/fixtures/async/http"

describe Async::HTTP::Server do
	include Sus::Fixtures::Async::HTTP::ServerContext
	include Sus::Fixtures::OpenSSL::ValidCertificateContext
	
	with "application layer protocol negotiation" do
		let(:server_context) do
			OpenSSL::SSL::SSLContext.new.tap do |context|
				context.cert = certificate
				
				context.alpn_select_cb = lambda do |protocols|
					protocols.last
				end
				
				context.key = key
			end
		end
		
		let(:client_context) do
			OpenSSL::SSL::SSLContext.new.tap do |context|
				context.cert_store = certificate_store
				
				context.alpn_protocols = ["h2", "http/1.1"]
				
				context.verify_mode = OpenSSL::SSL::VERIFY_PEER
			end
		end
		
		def make_server_endpoint(bound_endpoint)
			::IO::Endpoint::SSLEndpoint.new(super, ssl_context: server_context)
		end
		
		def make_client_endpoint(bound_endpoint)
			::IO::Endpoint::SSLEndpoint.new(super, ssl_context: client_context)
		end
		
		it "client can get a resource via https" do
			response = client.get("/")
			
			expect(response).to be(:success?)
			expect(response.read).to be == "Hello World!"
		end
		
		with "an idle connection closed by the server" do
			let(:connections) {[]}
			
			def around
				level = Console.logger.level
				Console.logger.fatal!
				
				super
			ensure
				Console.logger.level = level
			end
			
			let(:app) do
				connections = self.connections
				
				Protocol::HTTP::Middleware.for do |request|
					connections << request.connection
					
					Protocol::HTTP::Response[200, {}, ["Hello World!"]]
				end
			end
			
			it "uses a fresh connection for a non-idempotent request" do
				first_response = client.get("/")
				first_response.read
				first_connection = first_response.connection
				
				closing = reactor.async do
					connections.first.close
				end
				
				first_connection.stream.io.to_io.wait_readable(1)
				
				second_response = client.post("/")
				
				expect(second_response).to be(:success?)
				expect(second_response.connection).not.to be == first_connection
				expect(connections.size).to be == 2
				closing.wait
			ensure
				first_response&.close
				second_response&.close
			end
		end
	end
end
