# frozen_string_literal: true
#
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

require 'async/io/host_endpoint'
require 'async/io/ssl_endpoint'
require 'async/io/ssl_socket'

require_relative 'protocol/http1'
require_relative 'protocol/https'

module Async
	module HTTP
		# Represents a way to connect to a remote HTTP server.
		class Endpoint < Async::IO::Endpoint
			def self.parse(string, endpoint = nil, **options)
				url = URI.parse(string).normalize
				
				return self.new(url, endpoint, **options)
			end
			
			# Construct an endpoint with a specified scheme, hostname, optional path, and options.
			def self.for(scheme, hostname, path = "/", **options)
				# TODO: Consider using URI.for once it becomes available:
				uri_klass = URI.scheme_list[scheme.upcase] || URI::HTTP
				
				self.new(
					uri_klass.new(scheme, nil, hostname, nil, nil, path, nil, nil, nil).normalize,
					**options
				)
			end
			
			# @option scheme [String] the scheme to use, overrides the URL scheme.
			# @option hostname [String] the hostname to connect to (or bind to), overrides the URL hostname (used for SNI).
			# @option port [Integer] the port to bind to, overrides the URL port.
			# @option ssl_context [OpenSSL::SSL::SSLContext] the context to use for TLS.
			# @option alpn_protocols [Array<String>] the alpn protocols to negotiate.
			def initialize(url, endpoint = nil, **options)
				super(**options)
				
				raise ArgumentError, "URL must be absolute (include scheme, host): #{url}" unless url.absolute?
				
				@url = url
				
				if endpoint
					@endpoint = self.build_endpoint(endpoint)
				else
					@endpoint = nil
				end
			end
			
			def to_url
				url = @url.dup
				
				unless default_port?
					url.port = self.port
				end
				
				return url
			end
			
			def to_s
				"\#<#{self.class} #{self.to_url} #{@options}>"
			end
			
			def inspect
				"\#<#{self.class} #{self.to_url} #{@options.inspect}>"
			end
			
			attr :url
			
			def address
				endpoint.address
			end
			
			def secure?
				['https', 'wss'].include?(self.scheme)
			end
			
			def protocol
				@options.fetch(:protocol) do
					if secure?
						Protocol::HTTPS
					else
						Protocol::HTTP1
					end
				end
			end
			
			def default_port
				secure? ? 443 : 80
			end
			
			def default_port?
				port == default_port
			end
			
			def port
				@options[:port] || @url.port || default_port
			end
			
			# The hostname is the server we are connecting to:
			def hostname
				@options[:hostname] || @url.hostname
			end
			
			def scheme
				@options[:scheme] || @url.scheme
			end
			
			def authority(ignore_default_port = true)
				if ignore_default_port and default_port?
					@url.hostname
				else
					"#{@url.hostname}:#{port}"
				end
			end
			
			# Return the path and query components of the given URL.
			def path
				buffer = @url.path || "/"
				
				if query = @url.query
					buffer = "#{buffer}?#{query}"
				end
				
				return buffer
			end
			
			def alpn_protocols
				@options.fetch(:alpn_protocols) {self.protocol.names}
			end
			
			def localhost?
				@url.hostname =~ /^(.*?\.)?localhost\.?$/
			end
			
			# We don't try to validate peer certificates when talking to localhost because they would always be self-signed.
			def ssl_verify_mode
				if self.localhost?
					OpenSSL::SSL::VERIFY_NONE
				else
					OpenSSL::SSL::VERIFY_PEER
				end
			end
			
			def ssl_context
				@options[:ssl_context] || OpenSSL::SSL::SSLContext.new.tap do |context|
					if alpn_protocols = self.alpn_protocols
						context.alpn_protocols = alpn_protocols
					end
					
					context.set_params(
						verify_mode: self.ssl_verify_mode
					)
				end
			end
			
			def build_endpoint(endpoint = nil)
				endpoint ||= tcp_endpoint
				
				if secure?
					# Wrap it in SSL:
					return Async::IO::SSLEndpoint.new(endpoint,
						ssl_context: self.ssl_context,
						hostname: @url.hostname,
						timeout: self.timeout,
					)
				end
				
				return endpoint
			end
			
			def endpoint
				@endpoint ||= build_endpoint
			end
			
			def bind(*arguments, &block)
				endpoint.bind(*arguments, &block)
			end
			
			def connect(&block)
				endpoint.connect(&block)
			end
			
			def each
				return to_enum unless block_given?
				
				self.tcp_endpoint.each do |endpoint|
					yield self.class.new(@url, endpoint, **@options)
				end
			end
			
			def key
				[@url, @options]
			end
			
			def eql? other
				self.key.eql? other.key
			end
			
			def hash
				self.key.hash
			end
			
			protected
			
			def tcp_options
				options = @options.dup
				
				options.delete(:scheme)
				options.delete(:port)
				options.delete(:hostname)
				options.delete(:ssl_context)
				options.delete(:alpn_protocols)
				options.delete(:protocol)
				
				return options
			end
			
			def tcp_endpoint
				Async::IO::Endpoint.tcp(self.hostname, port, **tcp_options)
			end
		end
	end
end
