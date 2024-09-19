# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2024, by Samuel Williams.

require "protocol/http/body/readable"
require "protocol/http/body/stream"

require_relative "writable"

module Async
	module HTTP
		module Body
			# A body which is designed for hijacked server responses - a response which uses a block to read and write the request and response bodies respectively.
			class Hijack < ::Protocol::HTTP::Body::Readable
				def self.response(request, status, headers, &block)
					::Protocol::HTTP::Response[status, headers, self.wrap(request, &block)]
				end
				
				def self.wrap(request = nil, &block)
					self.new(block, request&.body)
				end
				
				def initialize(block, input = nil)
					@block = block
					@input = input
					
					@task = nil
					@stream = nil
					@output = nil
				end
				
				# We prefer streaming directly as it's the lowest overhead.
				def stream?
					true
				end
				
				def call(stream)
					@block.call(stream)
				end
				
				attr :input
				
				# Has the producer called #finish and has the reader consumed the nil token?
				def empty?
					@output&.empty?
				end
				
				def ready?
					@output&.ready?
				end
				
				# Read the next available chunk.
				def read
					unless @output
						@output = Writable.new
						@stream = ::Protocol::HTTP::Body::Stream.new(@input, @output)
						
						@task = Task.current.async do |task|
							task.annotate "Streaming hijacked body."
							
							@block.call(@stream)
						end
					end
					
					return @output.read
				end
				
				def inspect
					"\#<#{self.class} #{@block.inspect}>"
				end
				
				def to_s
					"<Hijack #{@block.class}>"
				end
			end
		end
	end
end
