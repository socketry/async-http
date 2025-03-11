# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Thomas Morgan.
# Copyright, 2024, by Samuel Williams.

require "async/http/protocol/http"
require "async/http/a_protocol"

describe Async::HTTP::Protocol::HTTP1 do
	with ".new" do
		it "can configure the protocol" do
			protocol = subject.new(
				persistent: false,
				maximum_line_length: 4096,
			)
			
			expect(protocol.options).to have_keys(
				persistent: be == false,
				maximum_line_length: be == 4096,
			)
		end
	end
end
