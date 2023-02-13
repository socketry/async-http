# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2023, by Samuel Williams.

require 'async/http/protocol/http10'
require_relative 'shared_examples'

RSpec.describe Async::HTTP::Protocol::HTTP10, timeout: 2 do
	it_behaves_like Async::HTTP::Protocol
end
