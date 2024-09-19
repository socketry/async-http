# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2024, by Samuel Williams.

require "async/http/protocol/http10"
require "async/http/a_protocol"

describe Async::HTTP::Protocol::HTTP10 do
	it_behaves_like Async::HTTP::AProtocol
end
