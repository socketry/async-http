#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2025, by Samuel Williams.

require "csv"
require "json"
require "net/http"

require "protocol/http/header/authorization"

class RateLimitingError < StandardError; end

@user = ENV["GITHUB_USER"]
@token = ENV["GITHUB_TOKEN"]

unless @user && @token
	fail "export GITHUB_USER and GITHUB_TOKEN!"
end

def fetch_github_license(homepage_uri)
	%r{github.com/(?<owner>.+?)/(?<repo>.+)} =~ homepage_uri
	return nil unless repo
	
	url = URI.parse("https://api.github.com/repos/#{owner}/#{repo}/license")
	request = Net::HTTP::Get.new(url)
	
	request["user-agent"] = "fetch-github-licenses"
	request["authorization"] = Protocol::HTTP::Header::Authorization.basic(@user, @token)
	
	response = Net::HTTP.start(url.hostname) do |http|
		http.request(request)
	end
	
	case response
	when Net::HTTPOK
		JSON.parse(response.body).dig("license", "spdx_id")
	when Net::HTTPNotFound, Net::HTTPMovedPermanently, Net::HTTPForbidden
		nil
	else
		raise response.body
	end
end

def fetch_rubygem_license(name, version)
	url = URI.parse("https://rubygems.org/api/v2/rubygems/#{name}/versions/#{version}.json")
	response = Net::HTTP.get_response(url)
	
	case response
	when Net::HTTPOK
		body = JSON.parse(response.body)
		[name, body.dig("licenses", 0) || fetch_github_license(body["homepage_uri"])]
	when Net::HTTPNotFound
		[name, nil] # from a non rubygems remote
	when Net::HTTPTooManyRequests
		raise RateLimitingError
	else
		raise response.body
	end
rescue RateLimitingError
	sleep 1
	
	retry
end

threads = ARGF.map do |line|
	if line == "GEM\n" .. line.chomp.empty?
		/\A\s{4}(?<name>[a-z].+?) \((?<version>.+)\)\n\z/ =~ line
		
		Thread.new {fetch_rubygem_license(name, version)} if name
	end
end.compact

puts CSV.generate {|csv| threads.each {csv << _1.value}}
