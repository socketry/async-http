#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2025, by Samuel Williams.

require "csv"
require "json"
require "async/http/internet"

class RateLimitingError < StandardError; end

@internet = Async::HTTP::Internet.new

@user = ENV["GITHUB_USER"]
@token = ENV["GITHUB_TOKEN"]

unless @user && @token
	fail "export GITHUB_USER and GITHUB_TOKEN!"
end

GITHUB_HEADERS = {
	"user-agent" => "fetch-github-licenses",
	"authorization" => Protocol::HTTP::Header::Authorization.basic(@user, @token)
}

RUBYGEMS_HEADERS = {
	"user-agent" => "fetch-github-licenses"
}

def fetch_github_license(homepage_uri)
	%r{github.com/(?<owner>.+?)/(?<repo>.+)} =~ homepage_uri
	return nil unless repo
	
	response = @internet.get("https://api.github.com/repos/#{owner}/#{repo}/license", GITHUB_HEADERS)
	
	case response.status
	when 200
		return JSON.parse(response.read).dig("license", "spdx_id")
	when 404
		return nil
	else
		raise response.read
	end
ensure
	response.finish
end

def fetch_rubygem_license(name, version)
	response = @internet.get("https://rubygems.org/api/v2/rubygems/#{name}/versions/#{version}.json", RUBYGEMS_HEADERS)
	
	case response.status
	when 200
		body = JSON.parse(response.read)
		[name, body.dig("licenses", 0) || fetch_github_license(body["homepage_uri"])]
	when 404
		[name, nil] # from a non rubygems remote
	when 429
		raise RateLimitingError
	else
		raise response.read
	end
rescue RateLimitingError
	response.finish
	
	Console.warn(name) {"Rate limited..."}
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
	
	@internet.instance_variable_get(:@clients).each do |name, client|
		puts client.pool
	end
end
