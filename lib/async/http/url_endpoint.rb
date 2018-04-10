# Copyright, 2018, by Samuel G. D. Williams. <http://www.codeotaku.com>
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

require 'async/io/endpoint'
require 'async/io/ssl_socket'

require_relative 'protocol/http1'
require_relative 'protocol/https'

module Async
	module HTTP
		class URLEndpoint < Async::IO::Endpoint
			def self.parse(string, **options)
				self.new(URI.parse(string), **options)
			end
			
			def initialize(url, endpoint = nil, **options)
				super(**options)
				
				@url = url
				@endpoint = endpoint
			end
			
			def to_s
				"\#<#{self.class} #{@url} #{@options.inspect}>"
			end
			
			attr :url
			attr :options
			
			def address
				endpoint.address
			end
			
			def secure?
				['https', 'wss'].include?(@url.scheme)
			end
			
			def protocol
				if secure?
					Protocol::HTTPS
				else
					Protocol::HTTP1
				end
			end
			
			def default_port
				secure? ? 443 : 80
			end
			
			def port
				@url.port || default_port
			end
			
			def hostname
				@options.fetch(:hostname, @url.hostname)
			end
			
			DEFAULT_ALPN_PROTOCOLS = ['h2', 'http/1.1'].freeze
			
			def alpn_protocols
				@options.fetch(:alpn_protocols, DEFAULT_ALPN_PROTOCOLS)
			end
			
			def ssl_context
				@options[:ssl_context] || ::OpenSSL::SSL::SSLContext.new.tap do |context|
					if alpn_protocols = self.alpn_protocols
						context.alpn_protocols = alpn_protocols
					end
					
					context.set_params
				end
			end
			
			def endpoint
				unless @endpoint
					@endpoint = Async::IO::Endpoint.tcp(hostname, port)
					
					if secure?
						# Wrap it in SSL:
						@endpoint = Async::IO::SecureEndpoint.new(@endpoint,
							ssl_context: ssl_context,
							hostname: self.hostname
						)
					end
				end
				
				return @endpoint
			end
			
			def bind(*args, &block)
				endpoint.bind(*args, &block)
			end
			
			def connect(*args, &block)
				endpoint.connect(*args, &block)
			end
			
			def each
				return to_enum unless block_given?
				
				self.endpoint.each do |endpoint|
					yield self.class.new(@url, endpoint, @options)
				end
			end
		end
	end
end