# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require_relative "../../../../async/http/server"

Traces::Provider(Async::HTTP::Server) do
	def call(request)
		if trace_parent = request.headers["traceparent"]
			Traces.trace_context = Traces::Context.parse(trace_parent.join, request.headers["tracestate"], remote: true)
		end
		
		attributes = {
			'http.version': request.version,
			'http.method': request.method,
			'http.authority': request.authority,
			'http.scheme': request.scheme,
			'http.path': request.path,
			'http.user_agent': request.headers["user-agent"],
		}
		
		if length = request.body&.length
			attributes["http.request.length"] = length
		end
		
		if protocol = request.protocol
			attributes["http.protocol"] = protocol
		end
		
		Traces.trace("async.http.server.call", attributes: attributes) do |span|
			super.tap do |response|
				if status = response&.status
					span["http.status_code"] = status
				end
				
				if length = response&.body&.length
					span["http.response.length"] = length
				end
			end
		end
	end
end
