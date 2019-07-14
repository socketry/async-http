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
require_relative 'stream'

module Async
	module HTTP
		module Body
			# A body which is designed for hijacked connections.
			class Hijack < ::Protocol::HTTP::Body::Readable
				def self.response(request, status, headers, &block)
					::Protocol::HTTP::Response[status, headers, self.wrap(request, &block)]
				end
				
				def self.wrap(request, &block)
					self.new(request.body, &block)
				end
				
				def initialize(input = nil, &block)
					@input = input
					@block = block
					
					@task = nil
					@stream = nil
				end
				
				def call(stream)
					return @block.call(stream)
				end
				
				attr :input
				
				# Has the producer called #finish and has the reader consumed the nil token?
				def empty?
					if @stream
						@stream.empty?
					else
						false
					end
				end
				
				# Read the next available chunk.
				def read
					unless @task
						@stream = Stream.new(@input)
						
						@task = Task.current.async do |task|
							task.annotate "Streaming hijacked body."
							
							@block.call(@stream)
						end
					end
					
					return @stream.output.read
				end
				
				def inspect
					"\#<#{self.class} #{@block.inspect}>"
				end
			end
		end
	end
end
