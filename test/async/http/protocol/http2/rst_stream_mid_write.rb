# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "async/http/protocol/http2"
require "sus/fixtures/async/http"
require "protocol/http/body/file"

# Regression test for the RST_STREAM / partial-frame corruption bug.
#
# Root cause (see report.md / bug.md):
#   When the client sends RST_STREAM while the server is mid-frame-write,
#   Async::Stop is raised inside IO::Stream#syswrite.  drain's
#   `ensure buffer.clear` silently discards the bytes not yet written,
#   leaving the remote frame parser stuck waiting for the rest of the frame
#   — permanently hanging the HTTP/2 connection.
#
# The definitive unit test is in io-stream ("cancel mid-write" in
# test/io/stream/buffered.rb), which reliably triggers the syswrite race
# using a pipe with a known-small buffer.  This test verifies the observable
# outcome at the HTTP/2 level: after a stream reset during a large body write,
# the connection must remain usable for subsequent requests.
describe Async::HTTP::Protocol::HTTP2 do
	with "RST_STREAM during large body write" do
		include Sus::Fixtures::Async::HTTP::ServerContext
		let(:protocol) {subject}
		
		# 10 MiB body — large enough to keep the server writing across several
		# HTTP/2 flow-control windows, matching the real-world video-file scenario.
		BODY_SIZE = 10 * 1024 * 1024
		
		let(:app) do
			Protocol::HTTP::Middleware.for do |request|
				Protocol::HTTP::Response[200, {
					"content-type"   => "video/mp4",
					"content-length" => BODY_SIZE.to_s,
				}, Protocol::HTTP::Body::File.open("/dev/zero", size: BODY_SIZE)]
			end
		end
		
		it "connection is not permanently hung after stream reset mid-write" do
			# Simulate Chrome's video-seek behaviour: read a chunk to open the flow-control window and get the server output task into an active write loop, then send RST_STREAM.
			response1 = client.get("/")
			expect(response1.status).to be == 200
			# Open flow-control window; server starts writing:
			response1.body.read
			# RST_STREAM — may race with an in-progress write:
			response1.close
			
			# Allow the server to process the RST_STREAM and (with the bug) potentially corrupt the shared HTTP/2 connection:
			Fiber.scheduler.yield
			
			# A second request on the same connection must succeed without error.
			#
			# Two failure modes when the bug is present:
			#   1. Async::TimeoutError — the client reader task is stuck waiting for the missing bytes of the partial frame; no response ever arrives.
			#   2. Protocol::HTTP2::ProtocolError — drain's buffer.clear caused a misaligned frame; the reader parsed garbage as a DATA frame for stream_id=0 (connection-control stream), an illegal combination.
			second_response = nil
			begin
				Async::Task.current.with_timeout(2.0) do
					second_response = client.get("/")
					expect(second_response.status).to be == 200
					second_response.close
					second_response = nil
				end
			ensure
				second_response&.close rescue nil
			end
		end
	end
end
