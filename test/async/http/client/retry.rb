# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "async/http/client"

class RetryClient < Async::HTTP::Client
	def initialize(failures)
		@pool = FakePool.new
		@protocol = nil
		@retries = 3
		@scheme = "https"
		@authority = "example.com"
		@failures = failures
		@chunks = []
	end
	
	attr :chunks
	
	class FakePool
		def acquire
			Object.new
		end
		
		def release(connection)
		end
	end
	
	def make_response(request, connection, attempt)
		@chunks << request.body&.read
		
		if failure = @failures.shift
			raise failure
		end
		
		return Protocol::HTTP::Response[200, {}, ["OK"]]
	end
end

describe Async::HTTP::Client do
	with "retries" do
		it "rewinds idempotent request bodies after ambiguous failures" do
			client = RetryClient.new([EOFError.new])
			request = Protocol::HTTP::Request["PUT", "/", {}, ["Hello"]]
			
			response = client.call(request)
			
			expect(response).to be(:success?)
			expect(client.chunks).to be == ["Hello", "Hello"]
		end
		
		it "rewinds non-idempotent request bodies after refused requests" do
			client = RetryClient.new([Protocol::HTTP::RefusedError.new("Request not processed.")])
			request = Protocol::HTTP::Request["POST", "/", {}, ["Hello"]]
			
			response = client.call(request)
			
			expect(response).to be(:success?)
			expect(client.chunks).to be == ["Hello", "Hello"]
		end
	end
end
