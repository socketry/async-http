# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2023, by Samuel Williams.

require 'async/http/protocol/http10'
require 'async/http/a_protocol'
require 'async/http/a_graceful_stop'

describe Async::HTTP::Protocol::HTTP10 do
	it_behaves_like Async::HTTP::AProtocol
	it_behaves_like Async::HTTP::AGracefulStop
end
