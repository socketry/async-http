#!/usr/bin/env ruby

require 'csv'
require 'json'
require 'async/http/internet'

class RateLimitingError < StandardError; end

@internet = Async::HTTP::Internet.new
HEADERS = {'user-agent' => 'fetch-github-licenses'}

def fetch_github_license(homepage_uri)
	%r{github.com/(?<owner>.+?)/(?<repo>.+)} =~ homepage_uri
	return nil unless repo

	response = @internet.get("https://api.github.com/repos/#{owner}/#{repo}/license", HEADERS)
	
	case response.status
	when 200
		return JSON.parse(response.read).dig('license', 'spdx_id')
	when 404
		return nil
	else
		raise response.read
	end
ensure
	response.finish
end

def fetch_rubygem_license(name, version)
	response = @internet.get("https://rubygems.org/api/v2/rubygems/#{name}/versions/#{version}.json", HEADERS)
	
	case response.status
	when 200
		body = JSON.parse(response.read)
		[name, body.dig('licenses', 0) || fetch_github_license(body['homepage_uri'])]
	when 404
		[name, nil] # from a non rubygems remote
	when 429
		raise RateLimitingError
	else
		raise response.read
	end
rescue RateLimitingError
	response.finish
	
	Async::Task.current.sleep(1.0)
	
	retry
ensure
	response.finish
end

Sync do |parent|
	output = CSV.new($stdout)
	
	tasks = ARGF.map do |line|
		if line == "GEM\n" .. line.chomp.empty?
			/\A\s{4}(?<name>[a-z].+?) \((?<version>.+)\)\n\z/ =~ line
			
			parent.async do
				fetch_rubygem_license(name, version)
			end if name
		end
	end.compact
	
	tasks.each do |task|
		output << task.wait
	end
end
