# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2024, by Samuel Williams.
# Copyright, 2020, by Bruno Sutic.

require_relative "stream"

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
				
				module Connection
					def initialize(*)
						super
						
						@count = 0
						@reader = nil
						
						# Writing multiple frames at the same time can cause odd problems if frames are only partially written. So we use a semaphore to ensure frames are written in their entirety.
						@write_frame_guard = Async::Semaphore.new(1)
					end
					
					def synchronize(&block)
						@write_frame_guard.acquire(&block)
					end
					
					def to_s
						"\#<#{self.class} #{@count} requests, #{@streams.count} active streams>"
					end
					
					def as_json(...)
						to_s
					end
					
					def to_json(...)
						as_json.to_json(...)
					end
					
					attr :stream
					
					def http1?
						false
					end
					
					def http2?
						true
					end
					
					def start_connection
						@reader || read_in_background
					end
					
					def close(error = nil)
						# Ensure the reader task is stopped.
						if @reader
							reader = @reader
							@reader = nil
							reader.stop
						end
						
						super
					end
					
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
							rescue Async::Stop, ::IO::TimeoutError, ::Protocol::HTTP2::GoawayError => error
								# Error is raised if a response is actively reading from the
								# connection. The connection is silently closed if GOAWAY is
								# received outside the request/response cycle.
							rescue SocketError, IOError, EOFError, Errno::ECONNRESET, Errno::EPIPE => ignored_error
								# Ignore.
							rescue => error
								# Every other error.
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
					
					def peer
						@stream.io
					end
					
					attr :count
					
					def concurrency
						self.maximum_concurrent_streams
					end
					
					# Can we use this connection to make requests?
					def viable?
						@stream&.readable?
					end
					
					def reusable?
						!self.closed?
					end
					
					def version
						VERSION
					end
				end
			end
		end
	end
end
