# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Thomas Morgan.
# Copyright, 2024, by Samuel Williams.

require 'async/http/protocol/http'
require 'async/http/a_protocol'

describe Async::HTTP::Protocol::HTTP do
	with 'server' do
		include Sus::Fixtures::Async::HTTP::ServerContext
		let(:protocol) {subject}
		
		with 'http11 client' do
			it 'should make a successful request' do
				response = client.get('/')
				expect(response).to be(:success?)
				expect(response.version).to be == 'HTTP/1.1'
				response.read
			end
		end
		
		with 'http2 client' do
			def make_client(endpoint, **options)
				options[:protocol] = Async::HTTP::Protocol::HTTP2
				super
			end
			
			it 'should make a successful request' do
				response = client.get('/')
				expect(response).to be(:success?)
				expect(response.version).to be == 'HTTP/2'
				response.read
			end
		end
	end
end
