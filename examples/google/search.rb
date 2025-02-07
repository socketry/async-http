#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2024, by Samuel Williams.

require "async"
require "async/clock"
require "protocol/http/middleware"
require_relative "../../lib/async/http"

URL = "https://www.google.com/search"
ENDPOINT = Async::HTTP::Endpoint.parse(URL)

class Google < Protocol::HTTP::Middleware
	def search(term)
		Console.info(self) {"Searching for #{term}..."}
		
		self.get("/search?q=#{term}", {"user-agent" => "Hi Google!"})
	end
end

terms = %w{thoughtful fear size payment lethal modern recognise face morning sulky mountainous contain science snow uncle skirt truthful door travel snails closed rotten halting creator teeny-tiny beautiful cherries unruly level follow strip team things suggest pretty warm end cannon bad pig consider airport strengthen youthful fog three walk furry pickle moaning fax book ruddy sigh plate cakes shame stem faulty bushes dislike train sleet one colour behavior bitter suit count loutish squeak learn watery orange idiotic seat wholesale omniscient nostalgic arithmetic instruct committee puffy program cream cake whistle rely encourage war flagrant amusing fluffy prick utter wacky occur daily son check}

if count = ENV.fetch("COUNT", 20)&.to_i
	terms = terms.first(count)
end

Async do |task|
	client = Async::HTTP::Client.new(ENDPOINT)
	google = Google.new(client)
	
	google.search("null").finish
	
	duration = Async::Clock.measure do
		counts = terms.map do |term|
			task.async do
				response = google.search(term)
				[term, response.read.scan(term).count]
			end
		end.map(&:wait).to_h
		
		Console.info(self, name: "counts") {counts}
	end
	
	Console.info(self, name: "duration") {duration}
ensure
	google.close
end
