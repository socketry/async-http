# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2023, by Samuel Williams.

require 'async/http/body/slowloris'

require 'sus/fixtures/async'
require 'async/http/body/a_writable_body'

describe Async::HTTP::Body::Writable do
	include Sus::Fixtures::Async::ReactorContext
	
	let(:body) {subject.new}
	
	it_behaves_like Async::HTTP::Body::AWritableBody
end
