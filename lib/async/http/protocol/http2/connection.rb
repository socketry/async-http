# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2023, by Samuel Williams.
# Copyright, 2020, by Bruno Sutic.

require_relative 'stream'

require 'async/semaphore'

module Async
	module HTTP
		module Protocol
			module HTTP2
				HTTPS = 'https'.freeze
				SCHEME = ':scheme'.freeze
				METHOD = ':method'.freeze
				PATH = ':path'.freeze
				AUTHORITY = ':authority'.freeze
				STATUS = ':status'.freeze
				PROTOCOL = ':protocol'.freeze
				
				CONTENT_LENGTH = 'content-length'.freeze
				CONNECTION = 'connection'.freeze
				TRAILER = 'trailer'.freeze
				
				module Connection
					def initialize(*)
						super
						
						@count = 0
						@reader = nil
						
						# Writing multiple frames at the same time can cause odd problems if frames are only partially written. So we use a semaphore to ensure frames are written in their entirety.
						@write_frame_guard = Async::Semaphore.new(1)
					end
					
					def to_s
						"\#<#{self.class} #{@streams.count} active streams>"
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
						super
						
						# Ensure the reader task is stopped.
						if @reader
							reader = @reader
							@reader = nil
							reader.stop
						end
					end
					
					def write_frame(frame)
						# We don't want to write multiple frames at the same time.
						@write_frame_guard.acquire do
							super
						end
						
						@stream.flush
					end
					
					def write_frames(&block)
						@write_frame_guard.acquire do
							super
						end
						
						@stream.flush
					end
					
					def read_in_background(parent: Task.current)
						raise RuntimeError, "Connection is closed!" if closed?
						
						parent.async(transient: true) do |task|
							@reader = task
							
							task.annotate("#{version} reading data for #{self.class}.")
							
							task.defer_stop do
								while !self.closed?
									self.consume_window
									self.read_frame
								end
							rescue SocketError, IOError, EOFError, Errno::ECONNRESET, Errno::EPIPE, Async::Wrapper::Cancelled
								# Ignore.
							rescue ::Protocol::HTTP2::GoawayError => error
								# Error is raised if a response is actively reading from the
								# connection. The connection is silently closed if GOAWAY is
								# received outside the request/response cycle.
								if @reader
									self.close(error)
								end
							ensure
								# Don't call #close twice.
								if @reader
									self.close($!)
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
						@stream.connected?
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
