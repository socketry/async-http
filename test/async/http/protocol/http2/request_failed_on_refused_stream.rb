# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "async/http/protocol/http2"
require "sus/fixtures/async/http"

describe Async::HTTP::Protocol::HTTP2 do
	with "REFUSED_STREAM converts to RefusedError" do
		include Sus::Fixtures::Async::HTTP::ServerContext
		let(:protocol) {subject}
		
		let(:request_count) {Async::Variable.new}
		
		let(:app) do
			request_count = self.request_count
			count = 0
			
			Protocol::HTTP::Middleware.for do |request|
				count += 1
				request_count.value = count
				
				Protocol::HTTP::Response[200, {}, ["OK"]]
			end
		end
		
		it "retries non-idempotent request" do
			response = client.put("/", {}, ["Hello"])
			expect(response).to be(:success?)
			
			count = Async::Task.current.with_timeout(1.0){request_count.wait}
			expect(count).to be == 1
		end
	end
end
