# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2023, by Samuel Williams.

require 'async/http/server'
require 'async/http/client'
require 'async/http/endpoint'

require 'async/io/ssl_socket'

require 'async/rspec/reactor'
require 'async/rspec/ssl'

RSpec.describe Async::HTTP::Server, timeout: 5 do
	include_context Async::RSpec::Reactor
	include_context Async::RSpec::SSL::ValidCertificate
	
	describe "application layer protocol negotiation" do
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
		
		# Shared port for localhost network tests.
		let(:server_endpoint) {Async::HTTP::Endpoint.parse("https://localhost:6779", ssl_context: server_context)}
		let(:client_endpoint) {Async::HTTP::Endpoint.parse("https://localhost:6779", ssl_context: client_context)}
		
		it "client can get a resource via https" do
			server = Async::HTTP::Server.for(server_endpoint, protocol: Async::HTTP::Protocol::HTTP1) do |request|
				Protocol::HTTP::Response[200, {}, ['Hello World']]
			end
			
			client = Async::HTTP::Client.new(client_endpoint)
			
			Async do |task|
				server_task = task.async do
					server.run
				end
				
				response = client.get("/")
					
				expect(response).to be_success
				expect(response.read).to be == "Hello World"
				
				client.close
				server_task.stop
			end
		end
	end
end
