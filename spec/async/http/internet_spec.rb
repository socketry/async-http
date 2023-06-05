# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2023, by Samuel Williams.

require 'async/http/internet'
require 'async/reactor'

require 'json'

RSpec.describe Async::HTTP::Internet, timeout: 30 do
	include_context Async::RSpec::Reactor
	
	let(:headers) {[['accept', '*/*'], ['user-agent', 'async-http']]}
	
	after do
		subject.close
	end
	
	it "can fetch remote website" do
		response = subject.get("https://www.codeotaku.com/index", headers)
		
		expect(response).to be_success
		
		response.close
	end
	
	let(:sample) {{"hello" => "world"}}
	let(:body) {[JSON.dump(sample)]}
	
	it "can fetch remote json" do
		response = subject.post("https://httpbin.org/anything", headers, body)
		
		expect(response).to be_success
		expect{JSON.parse(response.read)}.to_not raise_error
	end
end
