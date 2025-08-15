def prepare
	require "traces/provider/async/http"
	require "traces/provider/async/http/protocol/http1/client"
	require "traces/provider/async/http/protocol/http2/client"
end
