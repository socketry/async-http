# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2023, by Samuel Williams.

require_relative 'writable_examples'

RSpec.describe Async::HTTP::Body::Writable do
	include_context Async::RSpec::Reactor
	
	it_behaves_like Async::HTTP::Body::Writable
end
