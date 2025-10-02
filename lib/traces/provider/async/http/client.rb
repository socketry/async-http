# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require_relative "../../../../async/http/client"

Traces::Provider(Async::HTTP::Client) do
	def call(request)
		attributes = {
			'http.method': request.method,
			'http.authority': request.authority || self.authority,
			'http.scheme': request.scheme || self.scheme,
			'http.path': request.path,
		}
		
		if protocol = request.protocol
			attributes["http.protocol"] = protocol
		end
		
		if length = request.body&.length
			attributes["http.request.length"] = length
		end
		
		Traces.trace("async.http.client.call", attributes: attributes) do |span|
			if context = Traces.trace_context
				request.headers["traceparent"] = context.to_s
				# request.headers['tracestate'] = context.state
			end
			
			super.tap do |response|
				if version = response&.version
					span["http.version"] = version
				end
				
				if status = response&.status
					span["http.status_code"] = status
				end
				
				if length = response.body&.length
					span["http.response.length"] = length
				end
			end
		end
	end
	
	def make_response(request, connection, attempt)
		attributes = {
			attempt: attempt,
		}
		
		Traces.trace("async.http.client.make_response", attributes: attributes) do
			super
		end
	end
end
