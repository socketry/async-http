# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Denis Talakevich.

require "async/http/client"
require "async/http/mock"
require "async/http/protocol/http2"
require "protocol/http2/server"
require "protocol/http2/stream"
require "sus/fixtures/async/scheduler_context"

require "async/queue"
require "io/stream"
require "socket"

describe Async::HTTP::Protocol::HTTP2 do
	include Sus::Fixtures::Async::SchedulerContext
	
	let(:response_headers) {[[":status", "200"]]}
	
	# A graceful GOAWAY is sent by the server *while it is still processing* the streams it
	# accepted, which {Async::HTTP::Server} does not do, so these tests drive a raw HTTP/2 server
	# over the sockets the mock endpoint hands out.
	let(:peers) {Async::Queue.new}
	let(:endpoint) {Async::HTTP::Mock::Endpoint.new(subject, "http", "localhost", queue: peers)}
	let(:client) {Async::HTTP::Client.new(endpoint, limit: 1)}
	
	def goaway_frame(last_stream_id)
		frame = Protocol::HTTP2::GoawayFrame.new
		frame.pack(last_stream_id, 0, "")
		
		return frame
	end
	
	def accept_connection(socket)
		server = Protocol::HTTP2::Server.new(Protocol::HTTP2::Framer.new(socket))
		server.read_connection_preface([])
		
		return server
	end
	
	# Reads frames until `count` requests have arrived, and returns their streams in the order
	# they were accepted.
	def accept_requests(server, count)
		streams = []
		
		while streams.size < count
			frame = server.read_frame
			
			if frame.is_a?(Protocol::HTTP2::HeadersFrame)
				streams << server.streams[frame.stream_id]
			end
		end
		
		return streams
	end
	
	# The first connection accepts three requests but tells the client it only processed the
	# first one; every later connection simply answers what it is given.
	def handle_connection(socket, index, processed)
		server = accept_connection(socket)
		
		if index == 1
			streams = accept_requests(server, 3)
			server.write_frame(goaway_frame(streams.first.id))
			
			# The response for the accepted stream arrives *after* the GOAWAY, exactly like nginx:
			processed << streams.first.id
			streams.first.send_headers(response_headers, Protocol::HTTP2::END_STREAM)
		else
			accept_requests(server, 2).each do |stream|
				stream.send_headers(response_headers, Protocol::HTTP2::END_STREAM)
			end
		end
		
		# Keep the connection alive until the client closes it:
		while true
			server.read_frame
		end
	rescue EOFError, Errno::EPIPE
		# The client closed the connection.
	ensure
		socket.close
	end
	
	with "a server which sends a graceful GOAWAY" do
		it "completes the requests the server accepted, and retries the rest" do
			connections = 0
			processed = []
			
			acceptor = Async(transient: true) do |task|
				while socket = peers.dequeue
					index = (connections += 1)
					
					task.async{handle_connection(socket, index, processed)}
				end
			end
			
			responses = 3.times.map do |index|
				Async do
					client.post("/#{index}", {}, ["body-#{index}"])
				end
			end.map(&:wait)
			
			# Every request completes, including the one which was in flight when the GOAWAY arrived:
			expect(responses.map(&:status)).to be == [200, 200, 200]
			
			# The first request was answered on the connection which was going away:
			expect(processed).to be == [1]
			
			# The two requests which the server did not process were retried on a new connection:
			expect(connections).to be == 2
		ensure
			client.close
			acceptor&.stop
		end
	end
	
	with "a connection which received a GOAWAY" do
		let(:sockets) {::Socket.pair(::Socket::AF_UNIX, ::Socket::SOCK_STREAM)}
		let(:connection) {Async::HTTP::Protocol::HTTP2::Client.new(IO::Stream(sockets.first))}
		
		def after(error = nil)
			sockets.each{|socket| socket.close unless socket.closed?}
			
			super
		end
		
		with "no streams left to drain" do
			def before
				super
				
				connection.open!
				connection.receive_goaway(goaway_frame(0))
			end
			
			it "is closed" do
				expect(connection).to be(:goaway_received?)
				expect(connection).not.to be(:draining?)
				expect(connection).to be(:closed?)
			end
			
			it "refuses new requests so that they are retried on another connection" do
				# The connection is already closed, but the request was still not processed, so it must be refused rather than failed:
				expect do
					connection.call(::Protocol::HTTP::Request["POST", "/", {}, ["Hello World"]])
				end.to raise_exception(::Protocol::HTTP::RefusedError)
			end
		end
		
		with "a stream still draining" do
			def before
				super
				
				connection.open!
				
				# One request is in flight, and the server tells us it is the last one it will process:
				response = connection.create_response
				
				connection.receive_goaway(goaway_frame(response.stream.id))
			end
			
			it "is not offered to new requests" do
				expect(connection).to be(:goaway_received?)
				expect(connection).to be(:draining?)
				expect(connection).not.to be(:closed?)
				
				expect(connection).not.to be(:reusable?)
				expect(connection).not.to be(:viable?)
			end
			
			it "refuses new requests so that they are retried on another connection" do
				expect do
					connection.call(::Protocol::HTTP::Request["POST", "/", {}, ["Hello World"]])
				end.to raise_exception(::Protocol::HTTP::RefusedError)
			end
			
			it "is not closed while the accepted stream is still in flight" do
				Async do
					connection.read_in_background
					
					# The pool retires a connection which is no longer reusable, but the stream the server accepted is still being processed, so the connection must stay open:
					connection.close
					
					expect(connection).not.to be(:closed?)
					expect(connection.streams).not.to be(:empty?)
				ensure
					connection.close(EOFError.new("Test finished!"))
				end.wait
			end
			
			it "is closed if there is no reader to drain it" do
				connection.close
				
				expect(connection).to be(:closed?)
			end
		end
		
		it "closes itself when the last drained stream completes on the sending side" do
			server = Protocol::HTTP2::Server.new(Protocol::HTTP2::Framer.new(sockets.last))
			server.open!
			
			connection.open!
			
			# The request body is still being written when the response arrives, so the stream is completed by this task rather than by the background reader:
			stream = connection.create_stream
			stream.send_headers([[":method", "POST"], [":path", "/"], [":authority", "localhost"]])
			
			connection.read_in_background
			
			server.read_frame
			server.write_frame(goaway_frame(stream.id))
			server.streams[stream.id].send_headers(response_headers, Protocol::HTTP2::END_STREAM)
			
			Async::Task.current.sleep(0.1)
			expect(connection).to be(:draining?)
			
			stream.send_data("body", Protocol::HTTP2::END_STREAM)
			Async::Task.current.sleep(0.1)
			
			expect(connection).to be(:closed?)
			expect(connection.framer).to be_nil
			expect(sockets.first).to be(:closed?)
		end
	end
end
