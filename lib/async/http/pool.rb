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

require 'async/logger'
require 'async/notification'

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
				@resources = {} # resource => count
				@available = Async::Notification.new
				
				@limit = limit
				@active = 0
				
				@constructor = block
			end
			
			# The number of allocated resources.
			attr :active
			
			# Whether there are resources which are currently in use.
			def busy?
				@resources.collect do |_,usage|
					return true if usage > 0
				end
				
				return false
			end
			
			# All allocated resources.
			attr :resources
			
			def empty?
				@resources.empty?
			end
			
			def acquire
				resource = wait_for_resource
				
				return resource unless block_given?
				
				begin
					yield resource
				ensure
					release(resource)
				end
			end
			
			# Make the resource resources and let waiting tasks know that there is something resources.
			def release(resource)
				# A resource that is not good should also not be reusable.
				if resource.reusable?
					reuse(resource)
				else
					retire(resource)
				end
			end
			
			def close
				@resources.each_key(&:close)
				@resources.clear
				
				@active = 0
			end
			
			def to_s
				"\#<#{self.class} resources=#{availability_string} limit=#{@limit.inspect}>"
			end
			
			protected
			
			def availability_string
				@resources.collect do |resource,usage|
					"#{usage}/#{resource.multiplex}#{resource.connected? ? '' : '*'}/#{resource.count}"
				end.join(";")
			end
			
			def reuse(resource)
				Async.logger.debug(self) {"Reuse #{resource}"}
				
				@resources[resource] -= 1
				
				@available.signal
			end
			
			def retire(resource)
				Async.logger.debug(self) {"Retire #{resource}"}
				
				@resources.delete(resource)
				
				@active -= 1
				
				resource.close
				
				@available.signal
			end
			
			def wait_for_resource
				# If we fail to create a resource (below), we will end up waiting for one to become resources.
				until resource = available_resource
					@available.wait
				end
				
				Async.logger.debug(self) {"Wait for resource #{resource}"}
				
				return resource
			end
			
			def create
				# This might return nil, which means creating the resource failed.
				if resource = @constructor.call
					@resources[resource] = 1
				end
				
				return resource
			end
			
			def available_resource
				# This is a linear search... not idea, but simple for now.
				@resources.each do |resource, count|
					if count < resource.multiplex
						# We want to use this resource... but is it connected?
						if resource.connected?
							@resources[resource] += 1
							
							return resource
						else
							retire(resource)
						end
					end
				end
				
				if !@limit or @active < @limit
					Async.logger.debug(self) {"No resources resources, allocating new one..."}
					
					@active += 1
					
					return create
				end
				
				return nil
			end
		end
	end
end
