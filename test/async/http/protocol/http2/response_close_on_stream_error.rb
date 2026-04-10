# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "async/http/protocol/http2"
require "sus/fixtures/async/http"
require "protocol/http/body/wrapper"

describe Async::HTTP::Protocol::HTTP2 do
	with "response body close on stream error" do
		include Sus::Fixtures::Async::HTTP::ServerContext
		let(:protocol) {subject}
		
		let(:body_closed) {Async::Variable.new}
		
		let(:app) do
			body_closed = self.body_closed
			
			Protocol::HTTP::Middleware.for do |request|
				inner_body = Protocol::HTTP::Body::Buffered.new(["Hello World"])
				
				tracking_body = Class.new(Protocol::HTTP::Body::Wrapper) do
					define_method(:close) do |error = nil|
						super(error)
						body_closed.value = true
					end
				end.new(inner_body)
				
				if request.respond_to?(:stream) && request.stream
					Async do
						sleep(0.01)
						request.stream.send_reset_stream(Protocol::HTTP2::NO_ERROR)
					end
					
					sleep(0.05)
				end
				
				Protocol::HTTP::Response[200, {}, tracking_body]
			end
		end
		
		it "closes the response body when the stream is reset before sending" do
			expect do
				response = client.get("/")
			end.to raise_exception(Exception)
			
			# Wait up to 1 second for the body to be closed. Without the fix,
			# close is never called and this times out → test failure.
			result = Async::Task.current.with_timeout(1.0) do
				body_closed.wait
			rescue Async::TimeoutError
				nil
			end
			
			expect(result).to be == true
		end
	end
end
