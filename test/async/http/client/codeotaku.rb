# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023, by Samuel Williams.

require 'async/http/client'
require 'async/http/endpoint'
require 'protocol/http/accept_encoding'

require 'sus/fixtures/async'

describe Async::HTTP::Client do
	include Sus::Fixtures::Async::ReactorContext
	
	let(:endpoint) {Async::HTTP::Endpoint.parse('https://www.codeotaku.com')}
	let(:client) {Async::HTTP::Client.new(endpoint)}
	
	it "should specify hostname" do
		expect(endpoint.hostname).to be == "www.codeotaku.com"
		expect(client.authority).to be == "www.codeotaku.com"
	end
		
	it 'can fetch remote resource' do
		response = client.get('/index')
		
		response.finish
		
		expect(response).not.to be(:failure?)
	end
	
	it "can request remote resource with compression" do
		compressor = Protocol::HTTP::AcceptEncoding.new(client)
		
		response = compressor.get("/index", {'accept-encoding' => 'gzip'})
		
		expect(response).to be(:success?)
		
		expect(response.body).to be_a Async::HTTP::Body::Inflate
		expect(response.read).to be(:start_with?, '<!DOCTYPE html>')
	end
end

