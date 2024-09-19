# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2024, by Samuel Williams.

require "async/http/body/hijack"

require "sus/fixtures/async"

describe Async::HTTP::Body::Hijack do
	include Sus::Fixtures::Async::ReactorContext
	
	let(:body) do
		subject.wrap do |stream|
			3.times do 
				stream.write(content)
			end
			stream.close_write
		end
	end
	
	let(:content) {"Hello World!"}
	
	with "#call" do
		let(:stream) {Async::HTTP::Body::Writable.new}
		
		it "should generate body using direct invocation" do
			body.call(stream)
			
			3.times do
				expect(stream.read).to be == content
			end
			
			expect(stream.read).to be_nil
			expect(stream).to be(:empty?)
		end
		
		it "should generate body using stream" do
			3.times do
				expect(body.read).to be == content
			end
			
			expect(body.read).to be_nil
			
			expect(body).to be(:empty?)
		end
	end
end
