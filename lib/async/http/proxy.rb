# frozen_string_literal: true
#
# Copyright, 2019, by Samuel G. D. Williams. <http://www.codeotaku.com>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require_relative 'client'
require_relative 'endpoint'

require_relative 'body/pipe'

module Async
	module HTTP
		# Wraps a client, address and headers required to initiate a connectio to a remote host using the CONNECT verb.
		# Behaves like a TCP endpoint for the purposes of connecting to a remote host.
		class Proxy
			class ConnectFailure < StandardError
				def initialize(response)
					super "Failed to connect: #{response.status}"
					@response = response
				end
				
				attr :response
			end
			
			module Client
				def proxy(endpoint, headers = nil)
					Proxy.new(self, endpoint.authority(false), headers)
				end
				
				# Create a client that will proxy requests through the current client.
				def proxied_client(endpoint, headers = nil)
					proxy = self.proxy(endpoint, headers)
					
					return self.class.new(proxy.wrap_endpoint(endpoint))
				end
				
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
			# @see Async::IO::Endpoint#tcp
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
				
				response = @client.connect(@address.to_s, @headers, input)
				
				if response.success?
					pipe = Body::Pipe.new(response.body, input)
					
					return pipe.to_io unless block_given?
					
					begin
						yield pipe.to_io
					ensure
						pipe.close
					end
				else
					# This ensures we don't leave a response dangling:
					response.close
					
					raise ConnectFailure, response
				end
			end
			
			# @return [Async::HTTP::Endpoint] an endpoint that connects via the specified proxy.
			def wrap_endpoint(endpoint)
				Endpoint.new(endpoint.url, self, **endpoint.options)
			end
		end
		
		Client.prepend(Proxy::Client)
	end
end
