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

require 'async/io/buffer'

module Async
	module HTTP
		module Body
			# A generic base class for wrapping body instances. Typically you'd override `#read`.
			class Readable
				# The consumer can call stop to signal that the stream output has terminated.
				def close(error = nil)
				end
				
				# Will read return any data?
				def empty?
					false
				end
				
				def length
					nil
				end
				
				# Read the next available chunk.
				def read
					nil
				end
				
				# Read all remaining chunks into a buffered body and close the underlying input.
				def finish
					# Internally, this invokes `self.each` which then invokes `self.close`.
					Buffered.for(self)
				end
				
				# Enumerate all chunks until finished, then invoke `#close`.
				def each
					while chunk = self.read
						yield chunk
						# chunk.clear
					end
				ensure
					self.close($!)
				end
				
				# Read all remaining chunks into a single binary string using `#each`.
				def join
					buffer = IO::Buffer.new
					
					self.each do |chunk|
						buffer << chunk
						chunk.clear
					end
					
					return buffer
				end
			end
		end
	end
end
