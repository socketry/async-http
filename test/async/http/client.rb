# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2017-2023, by Samuel Williams.

require_relative 'server_context'

require 'async/http/server'
require 'async/http/client'
require 'async/reactor'

require 'async/io/ssl_socket'
require 'async/http/endpoint'
require 'protocol/http/accept_encoding'

RSpec.describe Async::HTTP::Client, timeout: 5 do
	describe Async::HTTP::Protocol::HTTP1 do
		include_context Async::HTTP::Server
		let(:protocol) {described_class}
		
		it "client can get resource" do
			response = client.get("/")
			response.read
			expect(response).to be_success
		end
	end
	
	context 'non-existant host' do
		include_context Async::RSpec::Reactor
		
		let(:endpoint) {Async::HTTP::Endpoint.parse('http://the.future')}
		let(:client) {Async::HTTP::Client.new(endpoint)}
		
		it "should fail to connect" do
			expect do
				client.get("/")
			end.to raise_error(SocketError, /not known/)
		end
	end
	
	describe Async::HTTP::Protocol::HTTPS do
		include_context Async::RSpec::Reactor
		
		let(:endpoint) {Async::HTTP::Endpoint.parse('https://www.codeotaku.com')}
		let(:client) {Async::HTTP::Client.new(endpoint)}
		
		it "should specify hostname" do
			expect(endpoint.hostname).to be == "www.codeotaku.com"
			expect(client.authority).to be == "www.codeotaku.com"
		end
		
		it "can request remote resource" do
			2.times do
				response = client.get("/index")
				expect(response).to be_success
				response.finish
			end
			
			client.close
		end
		
		it "can request remote resource with compression" do
			compressor = Protocol::HTTP::AcceptEncoding.new(client)
			
			response = compressor.get("/index", {'accept-encoding' => 'gzip'})
			
			expect(response).to be_success
			
			expect(response.body).to be_kind_of Async::HTTP::Body::Inflate
			expect(response.read).to be_start_with('<!DOCTYPE html>')
			
			client.close
		end
	end
end
