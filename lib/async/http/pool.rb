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

module Async
	module HTTP
		# Pool behaviours
		# 
		# - Single request per connection (HTTP/1 without keep-alive)
		# - Multiple sequential requests per connection (HTTP1 with keep-alive)
		# - Multiplex requests per connection (HTTP2)
		# 
		# In general we don't know the policy until connection is established.
		#
		# This pool doesn't impose a maximum number of open resources, but it WILL block if there are no available resources and trying to allocate another one fails.
		#
		# Resources must respond to
		# 	#multiplex -> 1 or more.
		# 	#reusable? -> can be used again.
		#
		class Pool
			def initialize(limit = nil, &block)
				@available = {} # resource => count
				@waiting = []
				
				@limit = limit
				
				@constructor = block
			end
			
			attr :available
			
			def empty?
				@available.empty?
			end
			
			def acquire
				resource = wait_for_next_available
				
				return resource unless block_given?
				
				begin
					yield resource
				ensure
					release(resource)
				end
			end
			
			# Make the resource available and let waiting tasks know that there is something available.
			def release(resource)
				# A resource that is not good should also not be reusable.
				if resource.reusable?
					reuse(resource)
				else
					retire(resource)
				end
			end
			
			def close
				@available.each_key(&:close)
				@available.clear
			end
			
			protected
			
			def reuse(resource)
				Async.logger.debug(self) {"Reuse #{resource}"}
				
				@available[resource] -= 1
				
				if task = @waiting.pop
					task.resume
				end
			end
			
			def retire(resource)
				Async.logger.debug(self) {"Retire #{resource}"}
				
				@available.delete(resource)
				
				resource.close
			end
			
			def wait_for_next_available
				until resource = next_available
					@waiting << Fiber.current
					Task.yield
				end
				
				return resource
			end
			
			def create
				begin
					# This might fail, which is okay :)
					resource = @constructor.call
				rescue
					Async.logger.error "#{$!}: #{$!.backtrace}"
					return nil
				end
				
				@available[resource] = 1
				
				return resource
			end
			
			def next_available
				@available.each do |resource, count|
					if count < resource.multiplex
						# We want to use this resource... but is it good?
						if resource.good?
							@available[resource] += 1
							
							return resource
						else
							retire(resource)
						end
					end
				end
				
				if !@limit or @available.count < @limit
					Async.logger.debug(self) {"No available resources, allocating new one..."}
					
					return create
				end
			end
		end
	end
end
