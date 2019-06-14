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

require 'async/semaphore'

module Async
	module HTTP
		module Protocol
			module HTTP2
				HTTPS = 'https'.freeze
				SCHEME = ':scheme'.freeze
				METHOD = ':method'.freeze
				PATH = ':path'.freeze
				AUTHORITY = ':authority'.freeze
				STATUS = ':status'.freeze
				PROTOCOL = ':protocol'.freeze
				
				CONTENT_LENGTH = 'content-length'
				
				module Connection
					def initialize(*)
						super
						
						@count = 0
						@reader = nil
						
						# Writing multiple frames at the same time can cause odd problems if frames are only partially written. So we use a semaphore to ensure frames are written in their entirety.
						@write_frame_guard = Async::Semaphore.new(1)
					end
					
					attr :stream
					
					def http1?
						false
					end
					
					def http2?
						true
					end
					
					def start_connection
						@reader ||= read_in_background
					end
					
					def close(error = nil)
						@reader = nil
						
						super
					end
					
					def write_frame(frame)
						# We don't want to write multiple frames at the same time.
						@write_frame_guard.acquire do
							super
						end
					end
					
					def read_in_background(task: Task.current)
						task.async do |nested_task|
							nested_task.annotate("#{version} reading data for #{self.class}")
							
							begin
								while !self.closed?
									self.write_data
									self.read_frame
								end
							rescue EOFError, Async::Wrapper::Cancelled
								# Ignore.
							ensure
								close($!)
							end
						end
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
				end
			end
		end
	end
end
