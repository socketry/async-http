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

require_relative 'stream'

module Async
	module HTTP
		module Protocol
			module HTTP2
				HTTPS = 'https'.freeze
				SCHEME = ':scheme'.freeze
				METHOD = ':method'.freeze
				PATH = ':path'.freeze
				AUTHORITY = ':authority'.freeze
				REASON = 'reason'.freeze
				STATUS = ':status'.freeze
				VERSION = 'HTTP/2.0'.freeze
				
				CONTENT_LENGTH = 'content-length'
				
				module Connection
					def initialize(*)
						super
						
						@count = 0
						@reader = nil
						
						@promises = Async::Queue.new
					end
					
					attr :stream
					
					def start_connection
						@reader ||= read_in_background
					end
					
					def stop_connection(error)
						@reader = nil
					end
					
					def read_in_background(task: Task.current)
						task.async do |nested_task|
							nested_task.annotate("#{version} reading data for #{self.class}")
							
							begin
								# Even thought the connection might be logically closed, we are not done until all HTTP/2 streams are closed or the underlying I/O is closed.
								while !@stream.closed?
									self.read_frame
								end
							ensure
								stop_connection($!)
							end
						end
					end
					
					def receive_push_promise(*)
						@promises.enqueue(super)
					end
					
					attr :promises
					
					def peer
						@stream.io
					end
					
					attr :count
					
					def multiplex
						@remote_settings.maximum_concurrent_streams
					end
					
					# Can we use this connection to make requests?
					def connected?
						@stream.connected?
					end
					
					def reusable?
						!(self.closed? || @stream.closed?)
					end
					
					def version
						VERSION
					end
					
					def close
						Async.logger.debug(self) {"Closing connection"}
						
						@reader.stop if @reader
						@stream.close
					end
				end
			end
		end
	end
end
