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

require 'protocol/http/body/readable'
require 'protocol/http/body/stream'

require_relative 'writable'

module Async
	module HTTP
		module Body
			# A body which is designed for hijacked server responses - a response which uses a block to read and write the request and response bodies respectively.
			class Hijack < ::Protocol::HTTP::Body::Readable
				def self.response(request, status, headers, &block)
					::Protocol::HTTP::Response[status, headers, self.wrap(request, &block)]
				end
				
				def self.wrap(request = nil, &block)
					self.new(block, request&.body)
				end
				
				def initialize(block, input = nil)
					@block = block
					@input = input
					
					@task = nil
					@stream = nil
					@output = nil
				end
				
				# We prefer streaming directly as it's the lowest overhead.
				def stream?
					true
				end
				
				def call(stream)
					return @block.call(stream)
				end
				
				attr :input
				
				# Has the producer called #finish and has the reader consumed the nil token?
				def empty?
					@output&.empty?
				end
				
				def ready?
					@output&.ready?
				end
				
				# Read the next available chunk.
				def read
					unless @output
						@output = Writable.new
						@stream = ::Protocol::HTTP::Body::Stream.new(@input, @output)
						
						@task = Task.current.async do |task|
							task.annotate "Streaming hijacked body."
							
							@block.call(@stream)
						end
					end
					
					return @output.read
				end
				
				def inspect
					"\#<#{self.class} #{@block.inspect}>"
				end
				
				def to_s
					"<Hijack #{@block.class}>"
				end
			end
		end
	end
end
