# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require_relative "../../../../async/http/server"
require "metrics/provider"

Metrics::Provider(Async::HTTP::Server) do
	ASYNC_HTTP_SERVER_REQUEST_INITIATED = Metrics.metric("async.http.server.request.initiated", :counter, description: "The number of HTTP server requests initiated.")
	ASYNC_HTTP_SERVER_REQUEST_FINISHED = Metrics.metric("async.http.server.request.finished", :counter, description: "The number of HTTP server requests finished.")

	def call(request)
		ASYNC_HTTP_SERVER_REQUEST_INITIATED.emit(1, tags: ["method:#{request.method}"])
		
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
end
