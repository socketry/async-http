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
		class Headers
			def initialize(fields = [])
				@fields = fields
				@indexed = to_h
			end
			
			attr :fields
			
			def freeze
				return if frozen?
				
				@indexed = to_h
				
				super
			end
			
			def each(&block)
				@fields.each(&block)
			end
			
			def include? key
				self[key] != nil
			end
			
			# Delete all headers with the given key, and return the value of the last one, if any.
			def delete(key)
				values, @fields = @fields.partition do |field|
					field.first.downcase == key
				end
				
				if @indexed
					@indexed.delete(key)
				end
				
				if field = values.last
					return field.last
				end
			end
			
			def []= key, value
				@fields << [key, value]
				
				if @indexed
					key = key.downcase
					
					if current_value = @indexed[key]
						@indexed[key] = Array(current_value) << value
					else
						@indexed[key] = value
					end
				end
			end
			
			def [] key
				@indexed ||= to_h
				
				@indexed[key]
			end
			
			def to_h
				@fields.inject({}) do |hash, (key, value)|
					key = key.downcase
					
					if current_value = hash[key]
						hash[key] = Array(current_value) << value
					else
						hash[key] = value
					end
					
					hash
				end
			end
			
			def == other
				if other.is_a? Hash
					to_h == other
				else
					@fields == other.fields
				end
			end
		end
	end
end
