# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

def prepare
	require "traces/provider/async/http"
	require "traces/provider/async/http/protocol/http1/client"
	require "traces/provider/async/http/protocol/http2/client"
end
