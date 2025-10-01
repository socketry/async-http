# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require_relative "../../../../async/http/server"
require "metrics/provider"

Metrics::Provider(Async::HTTP::Server) do
	ASYNC_HTTP_SERVER_REQUEST_INITIATED = Metrics.metric("async.http.server.request.initiated", :counter, description: "The number of HTTP server requests initiated.")
	ASYNC_HTTP_SERVER_REQUEST_FINISHED = Metrics.metric("async.http.server.request.finished", :counter, description: "The number of HTTP server requests finished.")
	ASYNC_HTTP_SERVER_REQUEST_QUEUE_TIME = Metrics.metric("async.http.server.request.queue_time", :histogram, description: "The time spent waiting in queue before processing (in seconds), based on the x-request-start header.")

	def call(request)
		ASYNC_HTTP_SERVER_REQUEST_INITIATED.emit(1, tags: ["method:#{request.method}"])
		
		# Calculate queue time from x-request-start header if present
		if request_start_header = request.headers["x-request-start"]
			queue_time = calculate_queue_time(request_start_header.first)
			
			if queue_time
				ASYNC_HTTP_SERVER_REQUEST_QUEUE_TIME.emit(queue_time, tags: ["method:#{request.method}"])
			end
		end
		
		if response = super(request)
			ASYNC_HTTP_SERVER_REQUEST_FINISHED.emit(1, tags: ["method:#{request.method}", "status:#{response.status}"])
			return response
		else
			return nil
		end
	ensure
		unless response
			ASYNC_HTTP_SERVER_REQUEST_FINISHED.emit(1, tags: ["method:#{request.method}", "status:failed"])
		end
	end
	
	private
	
	# Parse x-request-start header and calculate queue time in seconds.
	# Supports formats:
	# - "t=1234567890.123" (nginx format with 't=' prefix)
	# - "1234567890.123" (Unix timestamp in seconds)
	def calculate_queue_time(header_value)
		return nil unless header_value
		
		# Remove 't=' prefix if present (nginx format)
		timestamp_string = header_value.sub(/^t=/, "")
		
		begin
			timestamp = Float(timestamp_string)
			
			current_time = Process.clock_gettime(Process::CLOCK_REALTIME)
			queue_time = current_time - timestamp
			
			# Sanity check: queue time should be positive
			if queue_time > 0
				return queue_time
			end
		rescue ArgumentError, TypeError
			# Invalid timestamp format, ignore
			return nil
		end
		
		return nil
	end
end
