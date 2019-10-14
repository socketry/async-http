#!/usr/bin/env ruby

require "async"
require "async/clock"
require "protocol/http/middleware"
require "../../lib/async/http"

URL = "https://www.google.com/search"
ENDPOINT = Async::HTTP::Endpoint.parse(URL)

class Google < Protocol::HTTP::Middleware
	def search(term)
		Async.logger.info(self) {"Searching for #{term}..."}
		
		self.get("/search?q=#{term}")
	end
end

Async do |task|
	client = Async::HTTP::Client.new(ENDPOINT)
	google = Google.new(client)
	
	google.search("null").finish
	
	terms = %w{cats dogs chickens pigs fish horse goat cow sheep mice alpaca pigeon tui kea weka}
	
	duration = Async::Clock.measure do
		counts = terms.map do |term|
			task.async do
				response = google.search(term)
				[term, response.read.scan(term).count]
			end
		end.map(&:wait).to_h
		
		pp counts
	end
	
	pp duration
ensure
	google.close
end
