# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2023, by Samuel Williams.

require 'async/http/body/hijack'

RSpec.describe Async::HTTP::Body::Hijack do
	include_context Async::RSpec::Reactor
	
	let(:content) {"Hello World!"}
	
	describe '#call' do
		let(:stream) {Async::HTTP::Body::Writable.new}
		
		subject do
			described_class.wrap do |stream|
				3.times do 
					stream.write(content)
				end
				stream.close
			end
		end
		
		it "should generate body using direct invocation" do
			subject.call(stream)
			
			3.times do
				expect(stream.read).to be == content
			end
			
			expect(stream.read).to be_nil
			expect(stream).to be_empty
		end
		
		it "should generate body using stream" do
			3.times do
				expect(subject.read).to be == content
			end
			
			expect(subject.read).to be_nil
			
			expect(subject).to be_empty
		end
	end
end
