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

require 'async/io/binary_string'

module Async
	module HTTP
		module Body
			# A generic base class for wrapping body instances. Typically you'd override `#read`.
			class Readable
				# Buffer any remaining body.
				def close
					Buffered.for(self)
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
				
				# The consumer can call stop to signal that the stream output has terminated.
				def stop(error)
				end
				
				# Enumerate all chunks until finished. If an error is thrown, #stop will be invoked.
				def each
					return to_enum unless block_given?
					
					while chunk = self.read
						yield chunk
					end
				rescue
					stop($!)
					
					raise
				end
				
				# Read all remaining chunks into a single binary string.
				def join
					buffer = IO::BinaryString.new
					
					self.each do |chunk|
						buffer << chunk
					end
					
					return buffer
				end
			end
		end
	end
end
