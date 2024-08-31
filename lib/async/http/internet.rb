# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2024, by Samuel Williams.
# Copyright, 2024, by Igor Sidorov.

require_relative 'client'
require_relative 'endpoint'

require 'protocol/http/middleware'
require 'protocol/http/body/buffered'
require 'protocol/http/accept_encoding'

module Async
	module HTTP
		class Internet
			def initialize(**options)
				@clients = Hash.new
				@options = options
			end
			
			# A cache of clients.
			# @attribute [Hash(URI, Client)]
			attr :clients
			
			def client_for(endpoint)
				key = host_key(endpoint)
				
				@clients.fetch(key) do
					@clients[key] = self.make_client(endpoint)
				end
			end
			
			# Make a request to the internet with the given `method` and `url`.
			#
			# If you provide non-frozen headers, they may be mutated.
			#
			# @parameter method [String] The request method, e.g. `GET`.
			# @parameter url [String] The URL to request, e.g. `https://www.codeotaku.com`.
			# @parameter headers [Hash | Protocol::HTTP::Headers] The headers to send with the request.
			# @parameter body [String | Protocol::HTTP::Body] The body to send with the request.
			def call(verb, url, *arguments, **options, &block)
				endpoint = Endpoint[url]
				client = self.client_for(endpoint)
				
				options[:authority] ||= endpoint.authority
				options[:scheme] ||= endpoint.scheme
				
				request = ::Protocol::HTTP::Request[verb, endpoint.path, *arguments, **options]
				
				response = client.call(request)
				
				return response unless block_given?
				
				begin
					yield response
				ensure
					response.close
				end
			end
			
			def close
				# The order of operations here is to avoid a race condition between iterating over clients (#close may yield) and creating new clients.
				clients = @clients.values
				@clients.clear
				
				clients.each(&:close)
			end
			
			::Protocol::HTTP::Methods.each do |name, verb|
				define_method(verb.downcase) do |url, *arguments, **options, &block|
					self.call(verb, url, *arguments, **options, &block)
				end
			end
			
			protected
			
			def make_client(endpoint)
				::Protocol::HTTP::AcceptEncoding.new(
					Client.new(endpoint, **@options)
				)
			end
			
			def host_key(endpoint)
				url = endpoint.url.dup
				
				url.path = ""
				url.fragment = nil
				url.query = nil
				
				return url
			end
		end
	end
end
