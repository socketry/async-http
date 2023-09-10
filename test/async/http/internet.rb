# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2023, by Samuel Williams.

require 'async/http/internet'
require 'async/reactor'

require 'json'
require 'sus/fixtures/async'

describe Async::HTTP::Internet do
	include Sus::Fixtures::Async::ReactorContext
	
	let(:internet) {subject.new}
	let(:headers) {[['accept', '*/*'], ['user-agent', 'async-http']]}
	
	it "can fetch remote website" do
		response = internet.get("https://www.codeotaku.com/index", headers)
		
		expect(response).to be(:success?)
		
		response.close
	end
	
	let(:sample) {{"hello" => "world"}}
	let(:body) {[JSON.dump(sample)]}
	
	# This test is increasingly flakey.
	it "can fetch remote json" do
		response = internet.post("https://httpbin.org/anything", headers, body)
		
		expect(response).to be(:success?)
		expect{JSON.parse(response.read)}.not.to raise_exception
	end
end
