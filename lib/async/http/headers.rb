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
			def initialize
				@hash = {}
			end
			
			def freeze
				return unless frozen?
				
				@hash.freeze
				
				super
			end
			
			def inspect
				@hash.inspect
			end
			
			def []= key, value
				@hash[symbolize(key)] = value
			end
			
			def [] key
				@hash[key]
			end
			
			def == other
				@hash == other.to_hash
			end
			
			def delete(key)
				@hash.delete(key)
			end
			
			def each
				return to_enum unless block_given?
				
				@hash.each do |key, value|
					yield stringify(key), value
				end
			end
			
			def symbolize(value)
				Headers[value]
			end
			
			def stringify(key)
				key.to_s.tr('_', '-')
			end
			
			def to_hash
				@hash
			end
			
			def to_http_hash
				Hash[@hash.map{|key, value| ["HTTP_#{key.to_s.upcase}", value]}]
			end
			
			def self.[] value
				value.downcase.tr('-', '_').to_sym
			end
		end
	end
end
