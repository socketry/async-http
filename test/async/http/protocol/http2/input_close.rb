# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "async/http/protocol/http2"
require "async/http/body/hijack"
require "async/promise"
require "sus/fixtures/async/http"

describe Async::HTTP::Protocol::HTTP2 do
	with "closed input and active output" do
		include Sus::Fixtures::Async::HTTP::ServerContext
		let(:protocol) {subject}
		
		let(:data) {"Hello World!"}
		let(:request_body) {Async::Promise.new}
		
		let(:app) do
			Protocol::HTTP::Middleware.for do |request|
				Async::HTTP::Body::Hijack.response(request, 200, {}) do |stream|
					stream.write("x" * 128 * 1024)
					stream.flush
					
					request_body.resolve(stream.read(data.bytesize))
				ensure
					stream.close
				end
			end
		end
		
		it "discards incoming data while continuing to write" do
			input = Async::HTTP::Body::Writable.new
			response = client.connect(authority: "localhost:1", body: input)
			
			response.body.close
			input.write(data)
			
			current_task = Async::Task.current
			received = current_task.with_timeout(1) do
				request_body.wait
			end
			
			expect(received).to be == data
			input.close_write
			
			current_task.with_timeout(1) do
				current_task.yield while client.pool.busy?
			end
			
			expect(client.pool).not.to be(:busy?)
		ensure
			input&.close
			response&.close
		end
	end
end
