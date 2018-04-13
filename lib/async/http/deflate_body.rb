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

require 'zlib'

module Async
	module HTTP
		class DeflateBody
			ENCODINGS = {
				'deflate' => -Zlib::MAX_WBITS,
				'zlib' => Zlib::MAX_WBITS,
				'gzip' => Zlib::MAX_WBITS | 16,
			}
			
			def self.for(body, encoding = 'gzip', level = Zlib::DEFAULT_COMPRESSION)
				self.new(body, Zlib::Deflate.new(level, ENCODINGS[encoding]))
			end
			
			def initialize(body, stream)
				@body = body
				@stream = stream
			end
			
			def read
				return if @stream.finished?
				
				if chunk = @body.read
					return @stream.deflate(chunk, Zlib::SYNC_FLUSH)
				else
					chunk = @stream.finish
					
					return chunk.empty? ? nil : chunk
				end
			end
			
			def close
				@body = @body.close
				
				return self
			end
			
			def join
				buffer = Async::IO::BinaryString.new
				
				while chunk = self.read
					buffer << chunk
				end
				
				return buffer
			end
			
			def finished?
				@body.finished?
			end
		end
		
		class InflateBody < DeflateBody
			def self.for(body, encoding = 'gzip')
				self.new(body, Zlib::Inflate.new(ENCODINGS[encoding]))
			end
			
			def read
				return if @stream.finished?
				
				if chunk = @body.read
					chunk = @stream.inflate(chunk)
				else
					chunk = @stream.finish
				end
				
				return chunk.empty? ? nil : chunk
			end
		end
	end
end
