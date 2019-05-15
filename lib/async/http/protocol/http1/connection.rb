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

require 'protocol/http1'

require_relative 'request'
require_relative 'response'

require_relative '../../body/chunked'
require_relative '../../body/fixed'
require_relative '../../body/remainder'

module Async
	module HTTP
		module Protocol
			module HTTP1
				class Connection < ::Protocol::HTTP1::Connection
					def initialize(stream, version)
						super(stream)
						
						@version = version
					end
					
					attr :version
					
					def http1?
						true
					end
					
					def http2?
						false
					end
					
					def read_line?
						@stream.read_until(CRLF)
					end
					
					# @return [Async::Wrapper] the underlying non-blocking IO.
					def hijack!
						@persistent = false
						
						@stream.flush
						
						return @stream.io
					end
					
					def peer
						@stream.io
					end
					
					attr :count
					
					def multiplex
						1
					end
					
					# Can we use this connection to make requests?
					def connected?
						@stream.connected?
					end
					
					def reusable?
						!@stream.closed?
						# !(self.closed? || @stream.closed?)
					end
					
					def close
						Async.logger.debug(self) {"Closing connection"}
						
						@stream.close
					end
					
					def read_chunked_body
						Body::Chunked.new(self)
					end
					
					def read_fixed_body(length)
						Body::Fixed.new(@stream, length)
					end
					
					def read_remainder_body
						Body::Remainder.new(@stream)
					end
					
					def read_upgrade_body(protocol)
						Body::Remainder.new(@stream, protocol: protocol)
					end
				end
			end
		end
	end
end
