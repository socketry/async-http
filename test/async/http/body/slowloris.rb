# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2023, by Samuel Williams.

require 'async/http/body/slowloris'

require 'sus/fixtures/async'
require 'async/http/body/a_writable_body'

describe Async::HTTP::Body::Slowloris do
	include Sus::Fixtures::Async::ReactorContext
	
	let(:body) {subject.new}
	
	it_behaves_like Async::HTTP::Body::AWritableBody
	
	it "closes body with error if throughput is not maintained" do
		body.write("Hello World")
		
		sleep 0.1
		
		expect do
			body.write("Hello World")
		end.to raise_exception(Async::HTTP::Body::Slowloris::ThroughputError, message: be =~ /Slow write/)
	end
	
	it "doesn't close body if throughput is exceeded" do
		body.write("Hello World")
		
		expect do
			body.write("Hello World")
		end.not.to raise_exception
	end
end
