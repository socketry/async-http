# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require_relative "../../../../../../async/http/protocol/http1/client"

Traces::Provider(Async::HTTP::Protocol::HTTP1::Client) do
	def write_request(...)
		Traces.trace("async.http.protocol.http1.client.write_request") do
			super
		end
	end
	
	def read_response(...)
		Traces.trace("async.http.protocol.http1.client.read_response") do
			super
		end
	end
end
