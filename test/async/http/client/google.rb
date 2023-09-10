# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2023, by Samuel Williams.

require 'async/http/client'
require 'async/http/endpoint'

require 'sus/fixtures/async'

describe Async::HTTP::Client do
	include Sus::Fixtures::Async::ReactorContext
	
	let(:endpoint) {Async::HTTP::Endpoint.parse('https://www.google.com')}
	let(:client) {Async::HTTP::Client.new(endpoint)}
	
	it 'can fetch remote resource' do
		response = client.get('/', 'accept' => '*/*')
		
		response.finish
		
		expect(response).not.to be(:failure?)
		
		client.close
	end
end
