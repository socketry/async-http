# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "async/http/protocol/http2"
require "sus/fixtures/async/scheduler_context"
require "socket"

describe Async::HTTP::Protocol::HTTP2::Server do
	include Sus::Fixtures::Async::SchedulerContext
	
	let(:sockets) {Socket.pair(Socket::PF_UNIX, Socket::SOCK_STREAM)}
	let(:stream) {IO::Stream(sockets.first)}
	let(:server) {subject.new(stream)}
	let(:request) do
		Object.new.tap do |request|
			def request.method = "GET"
			def request.path = "/"
			def request.send_response(response) = nil
		end
	end
	
	it "closes the request queue" do
		request = Object.new
		server.requests.enqueue(request)
		
		server.close
		
		expect(server.requests).to be(:closed?)
		expect(server.requests.dequeue).to be == request
		expect(server.requests.dequeue).to be_nil
		
		expect do
			server.requests.enqueue(Object.new)
		end.to raise_exception(Async::Queue::ClosedError)
	end
	
	it "waits for active requests to finish" do
		handler_started = Async::Promise.new
		handler_release = Async::Promise.new
		each_finished = Async::Promise.new
		
		server.requests.enqueue(request)
		
		each_task = Async do
			server.each do |incoming_request|
				expect(incoming_request).to be == request
				handler_started.resolve(nil)
				handler_release.wait
			end
			
			each_finished.resolve(nil)
		end
		
		handler_started.wait
		server.requests.close
		Fiber.scheduler.yield
		
		expect(each_finished).not.to be(:resolved?)
		
		handler_release.resolve(nil)
		each_task.wait
		
		expect(each_finished).to be(:resolved?)
	end
end
