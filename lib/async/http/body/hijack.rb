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
				# Create a response with this hijacked body.
				# @parameter request [Protocol::HTTP::Request] The request to hijack.
				# @parameter status [Integer] The HTTP status code.
				# @parameter headers [Hash] The response headers.
				# @returns [Protocol::HTTP::Response] The response with the hijacked body.
				def self.response(request, status, headers, &block)
					::Protocol::HTTP::Response[status, headers, self.wrap(request, &block)]
				end
				
				# Wrap a request body with a hijacked body.
				# @parameter request [Protocol::HTTP::Request | Nil] The request to hijack.
				# @returns [Hijack] The hijacked body instance.
				def self.wrap(request = nil, &block)
					self.new(block, request&.body)
				end
				
				# Initialize the hijacked body.
				# @parameter block [Proc] The block to call with the stream.
				# @parameter input [Protocol::HTTP::Body::Readable | Nil] The input body to read from.
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
				
				# Invoke the block with the given stream for bidirectional communication.
				# @parameter stream [Protocol::HTTP::Body::Stream] The stream to pass to the block.
				def call(stream)
					@block.call(stream)
				end
				
				attr :input
				
				# Has the producer called #finish and has the reader consumed the nil token?
				def empty?
					@output&.empty?
				end
				
				# Whether the body has output ready to be read.
				# @returns [Boolean | Nil]
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
				
				# @returns [String] A detailed representation of this body.
				def inspect
					"\#<#{self.class} #{@block.inspect}>"
				end
				
				# @returns [String] A short summary of this body.
				def to_s
					"<Hijack #{@block.class}>"
				end
			end
		end
	end
end
