# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2023, by Samuel Williams.

require_relative '../../body/writable'

module Async
	module HTTP
		module Protocol
			module HTTP2
				# A writable body which requests window updates when data is read from it.
				class Input < Body::Writable
					def initialize(stream, length)
						super(length)
						
						@stream = stream
						@remaining = length
					end
					
					def read
						if chunk = super
							# If we read a chunk fron the stream, we want to extend the window if required so more data will be provided.
							@stream.request_window_update
						end
						
						# We track the expected length and check we got what we were expecting.
						if @remaining
							if chunk
								@remaining -= chunk.bytesize
							elsif @remaining > 0
								raise EOFError, "Expected #{self.length} bytes, #{@remaining} bytes short!"
							elsif @remaining < 0
								raise EOFError, "Expected #{self.length} bytes, #{@remaining} bytes over!"
							end
						end
						
						return chunk
					end
				end
			end
		end
	end
end
