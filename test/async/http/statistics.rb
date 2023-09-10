# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2023, by Samuel Williams.

require 'async/http/statistics'
require 'sus/fixtures/async/http'

describe Async::HTTP::Statistics do
	include Sus::Fixtures::Async::HTTP::ServerContext
	
	let(:app) do
		Protocol::HTTP::Middleware.for do |request|
			statistics = subject.start
			
			response = Protocol::HTTP::Response[200, {}, ["Hello ", "World!"]]
			
			statistics.wrap(response) do |statistics, error|
				expect(statistics.sent).to be == 12
				expect(error).to be_nil
			end.tap do |response|
				expect(response.body).to receive(:complete_statistics)
			end
		end
	end
	
	it "client can get resource" do
		response = client.get("/")
		expect(response.read).to be == "Hello World!"
		
		expect(response).to be(:success?)
	end
end
