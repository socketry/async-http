# Copyright, 2017, by Samuel G. D. Williams. <http://www.codeotaku.com>
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
require_relative 'reference'

require 'json'

module Async
	module HTTP
		class JSONBody
			def initialize(body)
				@body = body
			end
			
			def close
				@body = @body.close
				
				return self
			end
			
			def join
				JSON.parse(@body.join, symbolize_names: true)
			end
			
			def self.dump(payload)
				JSON.dump(payload)
			end
			
			def finished?
				@body.finished?
			end
		end
		
		class Resource
			def initialize(client, reference = Reference.parse, headers = {}, max_redirects: 10)
				@client = client
				@reference = reference
				@headers = headers
				
				@max_redirects = max_redirects
			end
			
			def [] path
				self.class.new(@client, @reference.nest(path), @headers, max_redirects: @max_redirects)
			end
			
			def with(**headers)
				self.class.new(@client, @reference, @headers.merge(headers), max_redirects: @max_redirects)
			end
			
			def wrapper_for(content_type)
				if content_type == 'application/json'
					return JSONBody
				end
			end
			
			def prepare_body(payload)
				return [] if payload.nil?
				
				content_type = @headers['content-type']
				
				if wrapper = wrapper_for(content_type)
					return wrapper.dump(payload)
				else
					raise ArgumentError.new("Unsure how to convert payload to #{content_type}!")
				end
			end
			
			def process_response(response)
				content_type = response.headers['content-type']
				
				if wrapper = wrapper_for(content_type)
					response.body = wrapper.new(response.body)
				end
				
				return response
			end
			
			Client::VERBS.each do |verb|
				define_method(verb.downcase) do |payload = nil, **parameters, &block|
					reference = @reference.dup(nil, parameters)
					
					response = self.request(verb, reference.to_str, @headers, prepare_body(payload)) do |response|
						process_response(response)
					end
					
					return response
				end
			end
			
			def request(verb, location, *args)
				@max_redirects.times do
					@client.request(verb, location, *args) do |response|
						if response.redirection?
							verb = 'GET' unless response.preserve_method?
							location = response.headers['location']
						else
							return yield response
						end
					end
				end
				
				raise ArgumentError.new("Too many redirections!")
			end
		end
	end
end
