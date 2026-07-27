# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "async/http/protocol/http1/connection"

require "io/stream"

require "sus/fixtures/async/reactor_context"
require "sus/fixtures/console"
require "sus/fixtures/openssl/verified_certificate_context"
require "sus/fixtures/openssl/valid_certificate_context"

describe Async::HTTP::Protocol::HTTP1::Connection do
	include Sus::Fixtures::Async::ReactorContext
	include Sus::Fixtures::Console::CapturedLogger
	include Sus::Fixtures::OpenSSL::VerifiedCertificateContext
	include Sus::Fixtures::OpenSSL::ValidCertificateContext
	
	before do
		listener = TCPServer.new("localhost", 0)
		port = listener.local_address.ip_port
		
		@sockets = [
			TCPSocket.new("localhost", port),
			listener.accept,
		]
		listener.close
		
		client_socket = OpenSSL::SSL::SSLSocket.new(@sockets[0], client_context)
		server_socket = OpenSSL::SSL::SSLSocket.new(@sockets[1], server_context)
		
		client_socket.sync_close = true
		server_socket.sync_close = true
		
		accept = reactor.async do
			server_socket.accept
		end
		
		connect = reactor.async do
			client_socket.connect
		end
		
		[accept, connect].each(&:wait)
		
		@client = IO::Stream::Buffered.wrap(client_socket)
		@server = IO::Stream::Buffered.wrap(server_socket)
		@connection = subject.new(@client, "HTTP/1.1")
	end
	
	after do
		@client&.close
		@server&.close
		
		@sockets.each do |socket|
			unless socket.closed?
				socket.close
			end
		end
	end
	
	attr :client
	attr :server
	attr :connection
	
	it "remains viable when an idle TLS connection would block" do
		expect(connection).to be(:viable?)
	end
	
	it "is not viable while active" do
		connection.state = :open
		
		expect(connection).not.to be(:viable?)
	end
	
	it "is not viable without a stream" do
		connection = subject.new(nil, "HTTP/1.1")
		
		expect(connection).not.to be(:viable?)
	end
	
	it "is not viable after a TLS close notification" do
		closing = reactor.async do
			server.close
		end
		
		@sockets.first.wait_readable(1)
		
		expect(connection).not.to be(:viable?)
		closing.wait
	end
	
	it "is not viable after an abrupt TLS disconnect" do
		@sockets.last.close
		@server = nil
		
		@sockets.first.wait_readable(1)
		
		expect(connection).not.to be(:viable?)
		expect_console.to have_logged(
			severity: be == :debug,
			subject: be_equal(connection),
			message: be == "Connection viability probe failed!",
			event: have_keys(type: be == :failure)
		)
	end
	
	it "is not viable when application data is pending while idle" do
		server.write("H")
		server.flush
		
		@sockets.first.wait_readable(1)
		
		expect(connection).not.to be(:viable?)
		expect(client.read(1)).to be == "H"
	end
end
