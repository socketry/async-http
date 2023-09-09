# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2023, by Samuel Williams.

require_relative 'writable_examples'

require 'async/http/body/slowloris'

RSpec.describe Async::HTTP::Body::Slowloris do
	include_context Async::RSpec::Reactor
	
	it_behaves_like Async::HTTP::Body::Writable
	
	it "closes body with error if throughput is not maintained" do
		subject.write("Hello World")
		
		sleep 0.1
		
		expect do
			subject.write("Hello World")
		end.to raise_error(Async::HTTP::Body::Slowloris::ThroughputError, /Slow write/)
	end
	
	it "doesn't close body if throughput is exceeded" do
		subject.write("Hello World")
		
		expect do
			subject.write("Hello World")
		end.to_not raise_error
	end
end
