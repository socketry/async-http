# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2017-2023, by Samuel Williams.

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
