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
		# A relative reference, excluding any authority.
		class Reference
			def initialize(path, query_string, fragment, parameters)
				@path = path
				@query_string = query_string
				@fragment = fragment
				@parameters = parameters
			end
			
			def self.[] reference
				if reference.is_a? self
					return reference
				else
					return self.parse(reference)
				end
			end
			
			# Generate a reference from a path and user parameters. The path may contain a `#fragment` or `?query=parameters`.
			def self.parse(path = '/', parameters = nil)
				base, fragment = path.split('#', 2)
				path, query_string = base.split('?', 2)
				
				self.new(path, query_string, fragment, parameters)
			end
			
			# The path component, e.g. /foo/bar/index.html
			attr :path
			
			# The un-parsed query string, e.g. 'x=10&y=20'
			attr :query_string
			
			# A fragment, the part after the '#'
			attr :fragment
			
			# User supplied parameters that will be appended to the query part.
			attr :parameters
			
			def parameters?
				@parameters and !@parameters.empty?
			end
			
			def query_string?
				@query_string and !@query_string.empty?
			end
			
			def fragment?
				@fragment and !@fragment.empty?
			end
			
			def append(buffer)
				if query_string?
					buffer << escape_path(@path) << '?' << @query_string
					buffer << '&' << encode(@parameters) if parameters?
				else
					buffer << escape_path(@path)
					buffer << '?' << encode(@parameters) if parameters?
				end
				
				if fragment?
					buffer << '#' << escape(@fragment)
				end
				
				return buffer
			end
			
			def to_str
				append(String.new)
			end
			
			alias to_s to_str
			
			def + other
				other = self.class[other]
				
				self.class.new(
					expand_path(self.path, other.path),
					other.query_string,
					other.fragment,
					other.parameters,
				)
			end
			
			def [] parameters
				self.dup(nil, parameters)
			end
			
			def dup(path = nil, parameters = nil)
				if @parameters
					if parameters
						parameters = @parameters.merge(parameters)
					else
						parameters = @parameters
					end
				end
				
				if path
					path = @path + '/' + path
				else
					path = @path
				end
				
				self.class.new(path, @query_string, @fragment, parameters)
			end
			
			private
			
			def expand_path(base, relative)
				if relative.start_with? '/'
					return relative
				else
					path = base.split('/')
					parts = relative.split('/')
					
					parts.each do |part|
						if part == '..'
							path.pop
						else
							path << part
						end
					end
					
					return path.join('/')
				end
			end
			
			# Escapes a generic string, using percent encoding.
			def escape(string)
				encoding = string.encoding
				string.b.gsub(/([^a-zA-Z0-9_.\-]+)/) do |m|
					'%' + m.unpack('H2' * m.bytesize).join('%').upcase
				end.force_encoding(encoding)
			end
			
			# According to https://tools.ietf.org/html/rfc3986#section-3.3, we escape non-pchar.
			NON_PCHAR = /([^a-zA-Z0-9_\-\.~!$&'()*+,;=:@\/]+)/.freeze
			
			# Escapes a path
			def escape_path(path)
				encoding = path.encoding
				path.b.gsub(NON_PCHAR) do |m|
					'%' + m.unpack('H2' * m.bytesize).join('%').upcase
				end.force_encoding(encoding)
			end
			
			# Encodes a hash or array into a query string
			def encode(value, prefix = nil)
				case value
				when Array
					return value.map { |v|
						encode(v, "#{prefix}[]")
					}.join("&")
				when Hash
					return value.map { |k, v|
						encode(v, prefix ? "#{prefix}[#{escape(k.to_s)}]" : escape(k.to_s))
					}.reject(&:empty?).join('&')
				when nil
					return prefix
				else
					raise ArgumentError, "value must be a Hash" if prefix.nil?
					
					return "#{prefix}=#{escape(value.to_s)}"
				end
			end
		end
	end
end
