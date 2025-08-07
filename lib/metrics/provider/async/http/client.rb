# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require_relative "../../../../async/http/client"
require "metrics/provider"

Metrics::Provider(Async::HTTP::Client) do
	ASYNC_HTTP_CLIENT_REQUEST_INITIATED = Metrics.metric("async.http.client.request.initiated", :counter, description: "The number of HTTP client requests initiated.")
	ASYNC_HTTP_CLIENT_REQUEST_FINISHED = Metrics.metric("async.http.client.request.finished", :counter, description: "The number of HTTP client requests finished.")

	def make_response(request, connection, attempt)
		ASYNC_HTTP_CLIENT_REQUEST_INITIATED.emit(1, tags: ["method:#{request.method}"])
		
		response = super(request, connection, attempt)
		
		ASYNC_HTTP_CLIENT_REQUEST_FINISHED.emit(1, tags: ["method:#{request.method}", "status:#{response.status}"])
		
		return response
	ensure
		unless response
			ASYNC_HTTP_CLIENT_REQUEST_FINISHED.emit(1, tags: ["method:#{request.method}", "status:failed"])
		end
	end
end
