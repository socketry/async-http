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

module Async
	module HTTP
		module Body
			# General operations for interacting with a request or response body.
			module Reader
				# Read chunks from the body.
				# @yield [String] read chunks from the body.
				def each(&block)
					if @body
						@body.each(&block)
						@body = nil
					end
				end
				
				# Reads the entire request/response body.
				# @return [String] the entire body as a string.
				def read
					if @body
						buffer = @body.join
						@body = nil
						
						return buffer
					end
				end
				
				# Gracefully finish reading the body. This will buffer the remainder of the body.
				# @return [Buffered] buffers the entire body.
				def finish
					if @body
						body = @body.finish
						@body = nil
						
						return body
					end
				end
				
				# Write the body of the response to the given file path.
				def save(path, mode = ::File::WRONLY|::File::CREAT, *args)
					if @body
						::File.open(path, mode, *args) do |file|
							self.each do |chunk|
								file.write(chunk)
							end
						end
					end
				end
				
				# Close the connection as quickly as possible. Discards body. May close the underlying connection if necessary to terminate the stream.
				def close(error = nil)
					if @body
						@body.close(error)
						@body = nil
					end
				end
				
				# Whether there is a body?
				def body?
					@body and !@body.empty?
				end
			end
		end
	end
end
