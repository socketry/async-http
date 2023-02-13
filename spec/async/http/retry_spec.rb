# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2023, by Samuel Williams.

require_relative 'server_context'

require 'async/http/client'
require 'async/http/endpoint'

RSpec.describe 'consistent retry behaviour' do
	include_context Async::HTTP::Server
	let(:protocol) {Async::HTTP::Protocol::HTTP1}
	
	let(:delay) {0.1}
	let(:retries) {2}
	
	let(:server) do
		Async::HTTP::Server.for(@bound_endpoint) do |request|
			Async::Task.current.sleep(delay)
			Protocol::HTTP::Response[200, {}, []]
		end
	end
	
	def make_request(body)
		# This causes the first request to fail with "SocketError" which is retried:
		Async::Task.current.with_timeout(delay / 2, SocketError) do
			return client.get('/', {}, body)
		end
	end
	
	specify 'with nil body' do
		make_request(nil)
	end
	
	specify 'with empty array body' do
		make_request([])
	end
end
