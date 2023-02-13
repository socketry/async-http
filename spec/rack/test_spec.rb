# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2023, by Samuel Williams.

require 'rack/test'
require 'rack/builder'

require 'async'
require 'async/http'

RSpec.describe Rack::Test do
	include_context Async::RSpec::Reactor
	include Rack::Test::Methods
	
	let(:app) do
		Rack::Builder.new do
			def body(*chunks)
				body = Async::HTTP::Body::Writable.new
				
				Async do |task|
					chunks.each do |chunk|
						body.write(chunk)
						task.sleep(0.1)
					end
					
					body.close
				end
				
				return body
			end
			
			# This echos the body back.
			run lambda { |env| [200, {}, body("Hello", " ", "World", "!")] }
		end
	end
	
	it "can read response body" do
		get "/"
		
		expect(last_response.body).to be == "Hello World!"
	end
end
