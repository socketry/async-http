# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2023, by Samuel Williams.

require 'async/http/client'
require 'async/http/endpoint'

RSpec.describe Async::HTTP::Client, timeout: 5 do
	include_context Async::RSpec::Reactor
	
	let(:endpoint) {Async::HTTP::Endpoint.parse('https://www.google.com')}
	let(:client) {Async::HTTP::Client.new(endpoint)}
	
	it 'can fetch remote resource' do
		response = client.get('/', 'accept' => '*/*')
	
		response.finish
	
		expect(response).to_not be_failure
		
		client.close
	end
end
