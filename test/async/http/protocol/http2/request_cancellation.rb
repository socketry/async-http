# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "async/http/protocol/http2"
require "sus/fixtures/async/http"

describe Async::HTTP::Protocol::HTTP2 do
	include Sus::Fixtures::Async::HTTP::ServerContext
	
	let(:protocol) {subject}
	
	let(:app) do
		Protocol::HTTP::Middleware.for do |request|
			Async::Task.current.sleep(10) if request.path == "/slow"
			
			Protocol::HTTP::Response[200, {}, ["OK"]]
		end
	end
	
	it "cancels a timed-out request and reuses the connection" do
		connection = Async::HTTP::Protocol::HTTP2.client(client_endpoint.connect)
		task = Async::Task.current
		
		expect do
			task.with_timeout(0.1) do
				connection.call(Protocol::HTTP::Request["GET", "/slow", scheme: "http", authority: "localhost"])
			end
		end.to raise_exception(Async::TimeoutError)
		
		expect(connection.streams).to be(:empty?)
		
		response = connection.call(Protocol::HTTP::Request["GET", "/fast", scheme: "http", authority: "localhost"])
		expect(response).to be(:success?)
		expect(response.read).to be == "OK"
	ensure
		response&.close
		connection&.close
	end
end
