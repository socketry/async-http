# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2025, by Samuel Williams.
# Copyright, 2024, by Igor Sidorov.
# Copyright, 2024, by Hal Brodigan.

require "async/http/internet"
require "async/reactor"

require "json"
require "sus/fixtures/async"

describe Async::HTTP::Internet do
	include Sus::Fixtures::Async::ReactorContext
	
	let(:internet) {subject.new}
	let(:headers) {[["accept", "*/*"], ["user-agent", "async-http"]]}
	
	it "can fetch remote website" do
		response = internet.get("https://www.google.com/", headers)
		
		expect(response).to be(:success?)
		
		response.close
	end
	
	it "can accept URI::HTTP objects" do
		uri = URI.parse("https://www.google.com/")
		response = internet.get(uri, headers)
		
		expect(response).to be(:success?)
	ensure
		response&.close
	end
	
	let(:sample) {{"hello" => "world"}}
	let(:body) {[JSON.dump(sample)]}
	
	it "can fetch remote website when given custom endpoint instead of url" do
		ssl_context = OpenSSL::SSL::SSLContext.new
		ssl_context.set_params(verify_mode: OpenSSL::SSL::VERIFY_NONE)
		
		# example of site with invalid certificate that will fail to be fetched without custom SSL options
		endpoint = Async::HTTP::Endpoint.parse("https://expired.badssl.com", ssl_context: ssl_context)
		
		response = internet.get(endpoint, headers)
		
		expect(response).to be(:success?)
	ensure
		response&.close
	end
end
