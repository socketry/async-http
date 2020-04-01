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

require_relative '../../body/writable'

module Async
	module HTTP
		module Protocol
			module HTTP2
				# A writable body which requests window updates when data is read from it.
				class Input < Body::Writable
					def initialize(stream, length)
						super(length)
						
						@stream = stream
						@remaining = length
					end
					
					def read
						if chunk = super
							# If we read a chunk fron the stream, we want to extend the window if required so more data will be provided.
							@stream.request_window_update
						end
						
						# We track the expected length and check we got what we were expecting.
						if @remaining
							if chunk
								@remaining -= chunk.bytesize
							elsif @remaining > 0
								raise EOFError, "Expected #{self.length} bytes, #{@remaining} bytes short!"
							elsif @remaining < 0
								raise EOFError, "Expected #{self.length} bytes, #{@remaining} bytes over!"
							end
						end
						
						return chunk
					end
				end
			end
		end
	end
end
