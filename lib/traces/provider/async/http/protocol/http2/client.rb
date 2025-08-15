require_relative "../../../../../../async/http/protocol/http2/client"

Traces::Provider(Async::HTTP::Protocol::HTTP2::Client) do
	def write_request(...)
		Traces.trace("async.http.protocol.http2.client.write_request") do
			super
		end
	end
	
	def read_response(...)
		Traces.trace("async.http.protocol.http2.client.read_response") do
			super
		end
	end
end
