# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2024, by Samuel Williams.

require 'async/http/client'
require 'async/http/endpoint'

require 'protocol/http/accept_encoding'

require 'sus/fixtures/async'

describe Async::HTTP::Client do
	include Sus::Fixtures::Async::ReactorContext
	
	let(:endpoint) {Async::HTTP::Endpoint.parse('https://www.google.com')}
	let(:client) {Async::HTTP::Client.new(endpoint)}
	
	it "should specify a hostname" do
		expect(endpoint.hostname).to be == "www.google.com"
		expect(client.authority).to be == "www.google.com"
	end
	
	it 'can fetch remote resource' do
		response = client.get('/', 'accept' => '*/*')
		
		response.finish
		
		expect(response).not.to be(:failure?)
		
		client.close
	end
	
	it "can request remote resource with compression" do
		compressor = Protocol::HTTP::AcceptEncoding.new(client)
		
		response = compressor.get("/", {'accept-encoding' => 'gzip'})
		
		expect(response).to be(:success?)
		
		expect(response.body).to be_a Async::HTTP::Body::Inflate
		expect(response.read).to be(:start_with?, '<!doctype html>')
	end
end
