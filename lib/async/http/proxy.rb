# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2026, by Samuel Williams.

require_relative "client"
require_relative "endpoint"

require_relative "body/pipe"

module Async
	module HTTP
		# Wraps a client, address and headers required to initiate a connectio to a remote host using the CONNECT verb.
		# Behaves like a TCP endpoint for the purposes of connecting to a remote host.
		class Proxy
			# Raised when a CONNECT tunnel through a proxy cannot be established.
			class ConnectFailure < StandardError
				# The maximum number of bytes of the response body to read, see {body}.
				MAXIMUM_BODY_SIZE = 1024 * 8
				
				# Initialize the failure with the unsuccessful response.
				# @parameter response [Protocol::HTTP::Response] The failed response from the proxy.
				# @parameter body [String | Nil] The beginning of the response body, if any.
				def initialize(response, body = nil)
					super "Failed to connect: #{response.status}"
					@response = response
					@body = body
				end
				
				# @attribute [Protocol::HTTP::Response] The failed response from the proxy. It has already been closed.
				attr :response
				
				# @attribute [String | Nil] Up to {MAXIMUM_BODY_SIZE} bytes of the response body, which may explain why the proxy rejected the connection.
				#
				# The body is read before this error is raised, so a proxy which neither finishes the body nor closes the connection (e.g. an HTTP/1 response without `content-length` on a persistent connection) will delay the failure until the caller's own timeout, if any.
				attr :body
			end
			
			# Extends the socket returned by {Proxy#connect} so that closing it closes the entire tunnel.
			#
			# Closing the socket of a {Body::Pipe} only ends the CONNECT request body, so the CONNECT response would remain open (and the proxy connection busy) until the proxy closes its end of the tunnel. Instead, closing this socket finishes the pipe: the CONNECT response is closed immediately, and the CONNECT request is closed once any data already written to the socket has been forwarded. HTTP/2 then resets the stream and HTTP/1 closes the connection, neither of which can be reused after a tunnel anyway.
			module Tunnel
				# @parameter pipe [Body::Pipe] The pipe connected to the CONNECT request and response.
				# @returns [Socket] The socket for the pipe, which finishes the pipe when closed.
				def self.wrap(pipe)
					socket = pipe.to_io
					socket.extend(self)
					socket.instance_variable_set(:@pipe, pipe)
					
					return socket
				end
				
				# Finish the pipe, which also closes the socket.
				def close
					if pipe = @pipe
						@pipe = nil
						pipe.finish
					else
						super
					end
				end
			end
			
			# Extends {Async::HTTP::Client} with proxy capabilities.
			module Client
				# Create a proxy instance for the given endpoint.
				# @parameter endpoint [Endpoint] The target endpoint to tunnel to.
				# @parameter headers [Hash | Nil] Optional headers to send with the CONNECT request.
				# @returns [Proxy] A proxy instance for establishing tunnels.
				def proxy(endpoint, headers = nil)
					Proxy.new(self, endpoint.authority(false), headers)
				end
				
				# Create a client that will proxy requests through the current client.
				def proxied_client(endpoint, headers = nil)
					proxy = self.proxy(endpoint, headers)
					
					return self.class.new(proxy.wrap_endpoint(endpoint))
				end
				
				# Create an endpoint that connects via this proxy.
				# @parameter endpoint [Endpoint] The target endpoint.
				# @parameter headers [Hash | Nil] Optional headers for the CONNECT request.
				# @returns [Endpoint] An endpoint that tunnels through the proxy.
				def proxied_endpoint(endpoint, headers = nil)
					proxy = self.proxy(endpoint, headers)
					
					return proxy.wrap_endpoint(endpoint)
				end
			end
			
			# Prepare and endpoint which can establish a TCP connection to the remote system.
			# @param client [Async::HTTP::Client] the client which will be used as a proxy server.
			# @param host [String] the hostname or address to connect to.
			# @param port [String] the port number to connect to.
			# @param headers [Array] an optional list of headers to use when establishing the connection.
			# @see IO::Endpoint#tcp
			def self.tcp(client, host, port, headers = nil)
				self.new(client, "#{host}:#{port}", headers)
			end
			
			# Construct a endpoint that will use the given client as a proxy for HTTP requests.
			# @param client [Async::HTTP::Client] the client which will be used as a proxy server.
			# @param endpoint [Async::HTTP::Endpoint] the endpoint to connect to.
			# @param headers [Array] an optional list of headers to use when establishing the connection.
			def self.endpoint(client, endpoint, headers = nil)
				proxy = self.new(client, endpoint.authority(false), headers)
				
				return proxy.endpoint(endpoint.url)
			end
			
			# @param client [Async::HTTP::Client] the client which will be used as a proxy server.
			# @param address [String] the address to connect to.
			# @param headers [Array] an optional list of headers to use when establishing the connection.
			def initialize(client, address, headers = nil)
				@client = client
				@address = address
				@headers = ::Protocol::HTTP::Headers[headers].freeze
			end
			
			attr :client
			
			# Close the underlying client connection.
			def close
				@client.close
			end
			
			# Establish a TCP connection to the specified host.
			# @return [Socket] a connected bi-directional socket.
			def connect(&block)
				input = Body::Writable.new
				
				response = @client.connect(authority: @address, headers: @headers, body: input)
				
				if response.success?
					pipe = Body::Pipe.new(response.body, input)
					
					return Tunnel.wrap(pipe) unless block_given?
					
					begin
						yield pipe.to_io
					ensure
						pipe.finish
					end
				else
					# This ensures we don't leave a response dangling:
					input.close
					
					begin
						body = read_failure_body(response)
					ensure
						response.close
					end
					
					raise ConnectFailure.new(response, body)
				end
			end
			
			# @return [Async::HTTP::Endpoint] an endpoint that connects via the specified proxy.
			def wrap_endpoint(endpoint)
				Endpoint.new(endpoint.url, self, **endpoint.options)
			end
			
			private
			
			# Proxies often explain why they rejected a connection in the response body, so read the beginning of it. Failing to do so shouldn't hide the original failure.
			def read_failure_body(response)
				body = response.body
				return nil unless body
				
				buffer = String.new
				
				begin
					while buffer.bytesize < ConnectFailure::MAXIMUM_BODY_SIZE and chunk = body.read
						buffer << chunk
					end
				rescue IOError, SystemCallError, ::Protocol::HTTP::Error => error
					# Anything else, e.g. `Async::TimeoutError`, should propagate to the caller:
					Console.debug(self, "Failed to read proxy response body!", error)
				end
				
				return buffer.byteslice(0, ConnectFailure::MAXIMUM_BODY_SIZE)
			end
		end
		
		Client.prepend(Proxy::Client)
	end
end
