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

require_relative 'readable'

require 'zlib'

module Async
	module HTTP
		module Body
			class Deflate < Readable
				DEFAULT_LEVEL = Zlib::DEFAULT_COMPRESSION
				
				DEFLATE = -Zlib::MAX_WBITS
				GZIP =  Zlib::MAX_WBITS | 16
				
				ENCODINGS = {
					'deflate' => DEFLATE,
					'gzip' => GZIP,
				}
				
				def self.encoding_name(window_size)
					if window_size <= -8
						return 'deflate'
					elsif window_size >= 16
						return 'gzip'
					else
						return 'compress'
					end
				end
				
				def self.for(body, window_size = GZIP, level = DEFAULT_LEVEL)
					self.new(body, Zlib::Deflate.new(level, window_size))
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
			end
		end
	end
end