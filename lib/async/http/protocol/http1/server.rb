# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2026, by Samuel Williams.
# Copyright, 2020, by Igor Sidorov.
# Copyright, 2023, by Thomas Morgan.
# Copyright, 2024, by Anton Zhuravsky.
# Copyright, 2025, by Jean Boussier.

require_relative "connection"
require_relative "finishable"

require "console/event/failure"
require "protocol/http/body/stream"

module Async
	module HTTP
		module Protocol
			module HTTP1
				# Writes chunks from a streamable response body using HTTP/1.1 chunked transfer encoding.
				class ChunkedOutput
					def initialize(connection, trailer = nil)
						@connection = connection
						@trailer = trailer
					end

					def write(chunk)
						return 0 if chunk.empty?

						@connection.write_chunk(chunk)

						return chunk.bytesize
					end

					def close(error = nil)
						if connection = @connection
							@connection = nil

							connection.finish_chunked_body(@trailer, error)
						end
					end

					alias close_write close
				end

				# An HTTP/1 server connection that receives requests and sends responses.
				class Server < Connection
					# Initialize the HTTP/1 server connection.
					def initialize(...)
						super

						@ready = Async::Notification.new
						@body_task = nil
					end

					# Called when the connection is closed, signalling any waiting tasks.
					def closed(error = nil)
						super

						@body_task&.stop(error)
						@ready.signal
					end

					# Write a single chunk of data to the connection.
					def write_chunk(chunk)
						@stream.write("#{chunk.bytesize.to_s(16).upcase}\r\n")
						@stream.write(chunk)
						@stream.write(CRLF)

						@stream.flush
					end

					# Finish a chunked response body.
					def finish_chunked_body(trailer = nil, error = nil)
						return if closed?

						if trailer&.any?
							@stream.write("0\r\n")
							write_headers(trailer)
							@stream.write("\r\n")
						else
							@stream.write("0\r\n\r\n")
						end

						@stream.flush
					ensure
						send_end_stream! unless closed?
					end

					private def monitor_body_task(task, body_task)
						task.async(transient: true) do |subtask|
							subtask.annotate("Monitoring HTTP/1 response body for peer close.")

							until closed? or body_task.finished?
								@stream&.to_io&.wait_readable

								close unless @stream&.readable?
							end
						end
					end

					private def write_streamable_body(task, version, input, body, head, trailer)
						if head
							write_body(version, body, head, trailer)
							return
						end

						write_connection_header(version)
						@stream.write("transfer-encoding: chunked\r\n\r\n")
						@stream.flush

						output = ChunkedOutput.new(self, trailer)
						stream = ::Protocol::HTTP::Body::Stream.new(input, output)

						@body_task = task.async do |subtask|
							subtask.annotate("Streaming HTTP/1 response body.")

							body.call(stream)
						rescue => error
							output.close(error)
							raise
						ensure
							stream.close(error)
						end

						monitor = monitor_body_task(task, @body_task)

						@body_task.wait
					ensure
						monitor&.stop
						@body_task = nil
					end

					# Write a failure response with the given status code.
					# @parameter status [Integer] The HTTP status code to send.
					def fail_request(status)
						@persistent = false
						write_response(@version, status, {})
						write_body(@version, nil)
					rescue => error
						# At this point, there is very little we can do to recover:
						Console.debug(self, "Failed to write failure response!", error)
					end

					# Read the next incoming request from the connection.
					# @returns [Request | Nil] The next request, or `nil` if the connection is closed.
					def next_request
						if closed?
							return nil
						elsif !idle?
							@ready.wait
						end

						# Read an incoming request:
						return unless request = Request.read(self)

						unless persistent?(request.version, request.method, request.headers)
							@persistent = false
						end

						return request
					rescue ::Protocol::HTTP1::BadRequest
						fail_request(400)
						# Conceivably we could retry here, but we don't really know how bad the error is, so it's better to just fail:
						raise
					end

					# Server loop.
					def each(task: Task.current)
						task.annotate("Reading #{self.version} requests for #{self.class}.")

						while request = next_request
							# We have received complete request (line + headers), so defer stop until the response is generated.
							task.defer_stop do
								if body = request.body
									finishable = Finishable.new(body)
									request.body = finishable
								end

								response = yield(request, self)
								version = request.version
								body = response&.body

								if hijacked?
									body&.close
									return
								end

								# If a response was generated, send it:
								if response
									trailer = response.headers.trailer!
									headers = response.headers.header

									# Some operations in this method are long running, that is, it's expected that `body.call(stream)` could literally run indefinitely. In order to facilitate garbage collection, we want to nullify as many local variables before calling the streaming body. This ensures that the garbage collection can clean up as much state as possible during the long running operation, so we don't retain objects that are no longer needed.

									if body and protocol = response.protocol
										# We force a 101 response if the protocol is upgraded - HTTP/2 CONNECT will return 200 for success, but this won't be understood by HTTP/1 clients:
										write_response(@version, 101, headers)

										# At this point, the request body is hijacked, so we don't want to call #finish below.
										request = nil
										response = nil

										if body.stream?
											return body.call(write_upgrade_body(protocol))
										else
											write_upgrade_body(protocol, body)
										end
									elsif response.status == 101
										# This code path is to support legacy behavior where the response status is set to 101, but the protocol is not upgraded. This may not be a valid use case, but it is supported for compatibility. We expect the response headers to contain the `upgrade` header.
										write_response(@version, response.status, headers)

										# Same as above:
										request = nil
										response = nil

										if body.stream?
											return body.call(write_tunnel_body(version))
										else
											write_tunnel_body(version, body)
										end
									else
										write_response(@version, response.status, headers)

										if request.connect? and response.success?
											# Same as above:
											request = nil
											response = nil

											if body.stream?
												return body.call(write_tunnel_body(version))
											else
												write_tunnel_body(version, body)
											end
										else
											head = request.head?

											# Same as above:
											request = nil
											response = nil

											if body&.stream? and version == ::Protocol::HTTP1::Connection::HTTP11
												write_streamable_body(task, version, finishable, body, head, trailer)
											else
												write_body(version, body, head, trailer)
											end
										end
									end

									# We are done with the body:
									body = nil
								else
									# If the request failed to generate a response, it was an internal server error:
									write_response(@version, 500, {})
									write_body(version, nil)

									request&.finish
								end

								if finishable
									finishable.wait(@persistent)
								else
									# Do not remove this line or you will unleash the gods of concurrency hell.
									task.yield
								end
							rescue => error
								# We store error (as a local variable) for later use in the ensure block.
								raise
							ensure
								body&.close(error)
							end
						end
					end
				end
			end
		end
	end
end
