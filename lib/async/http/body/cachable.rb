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

require 'protocol/http/body/rewindable'
require 'protocol/http/body/streamable'

module Async
	module HTTP
		module Body
			class Cachable < ::Protocol::HTTP::Body::Rewindable
				def self.wrap(message, &block)
					if body = message.body
						# Create a rewindable body wrapping the message body:
						rewindable = ::Protocol::HTTP::Body::Rewindable.new(body)
						
						# Set the message body to the rewindable body:
						message.body = rewindable
						
						# Wrap the message with the callback:
						::Protocol::HTTP::Streamable.wrap(message) do
							rewindable.rewind
							
							yield message, rewindable
						end
					else
						yield message, nil
					end
				end
			end
		end
	end
end
