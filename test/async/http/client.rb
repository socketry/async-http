# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2017-2024, by Samuel Williams.

require 'async/http/server'
require 'async/http/client'
require 'async/reactor'

require 'async/io/ssl_socket'
require 'async/http/endpoint'
require 'protocol/http/accept_encoding'

require 'sus/fixtures/async'
require 'sus/fixtures/async/http'

describe Async::HTTP::Client do
	with 'basic server' do
		include Sus::Fixtures::Async::HTTP::ServerContext
		
		it "client can get resource" do
			response = client.get("/")
			response.read
			expect(response).to be(:success?)
		end
		
		with 'client' do
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
				
				it 'generates a JSON string' do
					expect(JSON.dump(client)).to be == client.to_json
				end
			end
		end
		
		with 'server' do
			with "#as_json" do
				it "generates a JSON representation" do
					expect(server.as_json).to be == {
						endpoint: server.endpoint.to_s,
						protocol: server.protocol,
						scheme: server.scheme,
					}
				end
				
				it 'generates a JSON string' do
					expect(JSON.dump(server)).to be == server.to_json
				end
			end
		end
	end
	
	with 'non-existant host' do
		include Sus::Fixtures::Async::ReactorContext
		
		let(:endpoint) {Async::HTTP::Endpoint.parse('http://the.future')}
		let(:client) {Async::HTTP::Client.new(endpoint)}
		
		it "should fail to connect" do
			expect do
				client.get("/")
			end.to raise_exception(SocketError, message: be =~ /not known/)
		end
	end
end
