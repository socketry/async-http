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

require 'async/queue'

module Async
	module HTTP
		class Body < Async::Queue
			def initialize
				super
				
				@finished = false
			end
			
			def finished?
				@finished
			end
			
			def each
				return if @finished
				
				while chunk = self.dequeue
					yield chunk
				end
				
				@finished = true
			end
			
			def read
				return if @finished
				
				unless chunk = self.dequeue
					@finished = true
				end
				
				return chunk
			end
			
			def join
				buffer = Async::IO::BinaryString.new
				
				self.each do |chunk|
					buffer << chunk
				end
				
				return buffer
			end
			
			alias join read
			
			def write(chunk)
				self.enqueue(chunk)
			end
			
			def finish
				self.enqueue(nil)
			end
		end
		
		class BufferedBody
			def initialize(body)
				@chunks = []
				@index = 0
				
				body.each do |chunk|
					@chunks << chunk
				end
			end
			
			def each(&block)
				while @index < @chunks.count
					yield @chunks[@index]
					@index += 1
				end
			end
			
			def read
				if chunk = @chunks[@index]
					@index += 1
				end
				
				return chunk
			end
			
			def join
				buffer = Async::IO::BinaryString.new
				
				self.each do |chunk|
					buffer << chunk
				end
				
				return buffer
			end
			
			def rewind
				@index = 0
			end
			
			def finished?
				true
			end
			
			module Reader
				def read
					self.body ? self.body.join : nil
				end
				
				def finish
					return if self.body.nil? or self.body.finished?
					
					unless self.body.is_a? BufferedBody
						self.body = BufferedBody.new(self.body)
					end
				end
			end
		end
		
		class ChunkedBody
			def initialize(protocol)
				@protocol = protocol
				@finished = false
			end
			
			def finished?
				@finished
			end
			
			def read
				return nil if @finished
				
				size = @protocol.read_line.to_i(16)
				
				if size == 0
					@protocol.read_line
					
					@finished = true
					
					return nil
				end
				
				chunk = @protocol.stream.read(size)
				@protocol.read_line # Consume the trailing CRLF
				
				return chunk
			end
			
			def each
				while chunk = self.read
					yield chunk
				end
			end
			
			def join
				buffer = Async::IO::BinaryString.new
				
				self.each do |chunk|
					buffer << chunk
				end
				
				return buffer
			end
			
			def finish
				self.each {}
			end
		end
		
		class FixedBody
			CHUNK_LENGTH = 1024*1024
			
			def initialize(length, stream)
				@length = length
				@remaining = length
				@stream = stream
			end
			
			def finished?
				@remaining == 0
			end
			
			def each
				while chunk = self.read
					yield chunk
				end
			end
			
			def read
				if @remaining > 0
					if chunk = @stream.read(CHUNK_LENGTH)
						@remaining -= chunk.bytesize
						
						return chunk
					end
				end
			end
			
			def join
				buffer = @stream.read(@remaining)
				
				@remaining = 0
				
				return buffer
			end
			
			alias join read
			
			def finish
				read
			end
		end
	end
end
