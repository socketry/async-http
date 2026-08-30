# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2026, by Samuel Williams.
# Copyright, 2020, by Bruno Sutic.
# Copyright, 2025, by Jean Boussier.

require_relative "stream"

require "protocol/http/peer"
require "async/semaphore"

module Async
	module HTTP
		module Protocol
			module HTTP2
				HTTPS = "https".freeze
				SCHEME = ":scheme".freeze
				METHOD = ":method".freeze
				PATH = ":path".freeze
				AUTHORITY = ":authority".freeze
				STATUS = ":status".freeze
				PROTOCOL = ":protocol".freeze
				
				CONTENT_LENGTH = "content-length".freeze
				CONNECTION = "connection".freeze
				TRAILER = "trailer".freeze
				
				# Provides shared connection behaviour for HTTP/2 client and server connections.
				module Connection
					# Initialize the connection state.
					def initialize(...)
						super
						
						@reader = nil
						
						# Writing multiple frames at the same time can cause odd problems if frames are only partially written. So we use a semaphore to ensure frames are written in their entirety.
						@write_frame_guard = Async::Semaphore.new(1)
					end
					
					# Synchronize write access to the connection.
					# @yields {|...| ...} The block to execute while holding the write lock.
					def synchronize(&block)
						@write_frame_guard.acquire(&block)
					end
					
					# Write a single frame, deferring stop until the frame is written.
					def write_frame(frame)
						Task.current.defer_stop{super}
					end
					
					# Write multiple frames, deferring stop until the frames are written.
					def write_frames
						Task.current.defer_stop{super}
					end
					
					# @returns [String] A string representation of this connection.
					def to_s
						"\#<#{self.class} #{@streams.count} active streams>"
					end
					
					# @returns [String] A JSON-compatible representation.
					def as_json(...)
						to_s
					end
					
					# @returns [String] A JSON string representation.
					def to_json(...)
						as_json.to_json(...)
					end
					
					attr :stream
					
					# @returns [Boolean] Whether this is an HTTP/1 connection.
					def http1?
						false
					end
					
					# @returns [Boolean] Whether this is an HTTP/2 connection.
					def http2?
						true
					end
					
					# Start the background reader task if it is not already running.
					def start_connection
						@reader || read_in_background
					end
					
					# Close the connection and stop the background reader.
					#
					# If the remote peer sent a graceful GOAWAY frame, the streams it accepted are still being processed and their responses are still on the way. Closing the connection now would fail those requests, even though the remote peer has already processed them. Instead we defer: the background reader closes the connection once the last stream completes. An explicit error still closes the connection immediately.
					def close(error = nil)
						if reader = @reader
							# Only the background reader can drain the connection, so if it is not running, there is nothing to wait for:
							return self if error.nil? and self.draining?
							
							@reader = nil
							
							# The reader task can close the connection itself, e.g. when the last stream completes and the connection is released back to the pool. Stopping it here would cancel the current task in the middle of this method, leaving the underlying stream open, so we let it unwind by itself: `closed?` is now true, so the read loop exits.
							reader.stop unless reader.current?
						end
						
						super
					end
					
					# The connection has finished draining the streams which the remote peer accepted before its graceful GOAWAY.
					#
					# The last of those streams can complete on the sending side, in a task other than the background reader - the response arrived first and the request body was still being written. The reader is then parked in a blocking read and will never notice that the connection is closed, so we stop it and let its `ensure` close the connection.
					def close_if_drained!
						super
						
						if self.closed? and (reader = @reader) and !reader.current?
							reader.stop
						end
					end
					
					# Start a transient background task that reads frames from the connection.
					def read_in_background(parent: Task.current)
						raise RuntimeError, "Connection is closed!" if closed?
						
						parent.async(transient: true) do |task|
							@reader = task
							
							task.annotate("#{version} reading data for #{self.class}.")
							
							# We don't need to defer stop here as this is already a transient task (ignores stop):
							begin
								while !self.closed?
									self.consume_window
									self.read_frame
								end
							rescue => error
								# Close with error.
							ensure
								# Don't call #close twice.
								if @reader
									@reader = nil
									
									self.close(error)
								end
							end
						end
					end
					
					attr :promises
					
					# @returns [Protocol::HTTP::Peer] The peer information for this connection.
					def peer
						@peer ||= ::Protocol::HTTP::Peer.for(@stream.io)
					end
					
					attr :count
					
					# @returns [Integer] The maximum number of concurrent streams allowed.
					def concurrency
						self.maximum_concurrent_streams
					end
					
					# Can we use this connection to make requests?
					def viable?
						!self.goaway_received? && @stream&.readable?
					end
					
					# @returns [Boolean] Whether the connection can be reused.
					#
					# Once the remote peer has sent a GOAWAY frame, it will not process any new streams on this connection, so it must not be handed out for another request, even while the streams it accepted are still being drained.
					def reusable?
						!self.closed? && !self.goaway_received?
					end
					
					# @returns [String] The HTTP version string.
					def version
						VERSION
					end
				end
			end
		end
	end
end
