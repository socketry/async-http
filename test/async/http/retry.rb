# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2024, by Samuel Williams.

require "async/http/client"
require "async/http/endpoint"

require "sus/fixtures/async/http"

describe "consistent retry behaviour" do
	include Sus::Fixtures::Async::HTTP::ServerContext
	
	let(:delay) {0.1}
	let(:retries) {2}
	
	let(:app) do
		Protocol::HTTP::Middleware.for do |request|
			sleep(delay)
			Protocol::HTTP::Response[200, {}, []]
		end
	end
	
	def make_request(body)
		# This causes the first request to fail with "SocketError" which is retried:
		Async::Task.current.with_timeout(delay / 2.0, SocketError) do
			return client.get("/", {}, body)
		end
	end
	
	it "retries with nil body" do
		response = make_request(nil)
		expect(response).to be(:success?)
	end
	
	it "retries with empty body" do
		response = make_request([])
		expect(response).to be(:success?)
	end
end
