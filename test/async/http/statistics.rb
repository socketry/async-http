# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2023, by Samuel Williams.

require_relative 'server_context'

require 'async/http/statistics'

RSpec.describe Async::HTTP::Statistics, timeout: 5 do
	include_context Async::HTTP::Server
	let(:protocol) {Async::HTTP::Protocol::HTTP1}
	
	let(:server) do
		Async::HTTP::Server.for(@bound_endpoint) do |request|
			statistics = described_class.start
			
			response = Protocol::HTTP::Response[200, {}, ["Hello ", "World!"]]
			
			statistics.wrap(response) do |statistics, error|
				expect(statistics.sent).to be == 12
				expect(error).to be_nil
			end.tap do |response|
				expect(response.body).to receive(:complete_statistics).and_call_original
			end
		end
	end
	
	it "client can get resource" do
		response = client.get("/")
		expect(response.read).to be == "Hello World!"
		
		expect(response).to be_success
	end
end
