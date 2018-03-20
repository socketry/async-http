#!/usr/bin/env ruby

require 'async/await'

require 'pry'

require_relative '../lib/async/http/client'
require '../lib/async/http/url_endpoint'
require '../lib/async/http/protocol/https'

require 'trenni/sanitize'
require 'set'

Async.logger.level = Logger::DEBUG

class HTML < Trenni::Sanitize::Filter
	def initialize(*)
		super
		
		@base = nil
		@links = []
	end
	
	attr :base
	attr :links
	
	def filter(node)
		if node.name == 'base'
			@base = node['href']
		elsif node.name == 'a'
			@links << node['href']
		end
		
		node.skip!(TAG)
	end
end

class Cache
	def initialize
		@clients = {}
	end
	
	def close
		@clients.each(&:close)
		@clients.clear
	end
	
	def [] endpoint
		url = endpoint.specification
		key = "#{url.scheme}://#{url.userinfo}@#{url.hostname}"
		
		@clients[key] ||= Async::HTTP::Client.new(endpoint, endpoint.secure? ? Async::HTTP::Protocol::HTTPS : Async::HTTP::Protocol::HTTP1)
	end
end

class << self
	include Async::Await
	
	async def fetch(url, depth = 4, fetched = Set.new, clients = Cache.new)
		return if fetched.include?(url) or depth == 0 or url.host != "www.codeotaku.com"
		fetched << url
		
		endpoint = Async::HTTP::URLEndpoint.new(url)
		client = clients[endpoint]
		
		request_uri = endpoint.specification.request_uri
		puts "GET #{url} (depth = #{depth})"
		
		response = timeout(10) do
			client.get(request_uri, {
				':authority' => endpoint.specification.hostname,
				'accept' => '*/*',
				'user-agent' => 'spider',
			})
		end
		
		if response.status >= 300 && response.status < 400
			location = url + response.headers['location']
			# puts "Following redirect to #{location}"
			return fetch(location, depth-1, fetched)
		end
		
		content_type = response.headers['content-type']
		unless content_type&.start_with? 'text/html'
			# puts "Unsupported content type: #{response.headers['content-type']}"
			return
		end
		
		base = endpoint.specification
		
		begin
			html = HTML.parse(response.body)
		rescue
			# Async.logger.error($!)
			return
		end
		
		if html.base
			base = base + html.base
		end
		
		html.links.each do |href|
			begin
				full_url = base + href
				
				fetch(full_url, depth - 1, fetched) if full_url.kind_of? URI::HTTP
			rescue ArgumentError, URI::InvalidURIError
				# puts "Could not fetch #{href}, relative to #{base}."
			end
		end
	rescue Async::TimeoutError
		Async.logger.error("Timeout while fetching #{url}")
	rescue StandardError
		Async.logger.error($!)
	ensure
		puts "Closing client from spider..."
		client.close if client
	end
	
	async def fetch_one(url)
		endpoint = Async::HTTP::URLEndpoint.new(url)
		client = Async::HTTP::Client.new(endpoint, endpoint.secure? ? Async::HTTP::Protocol::HTTPS : Async::HTTP::Protocol::HTTP1)
		
		binding.pry
	end
end

fetch_one(URI.parse("https://www.codeotaku.com"))
#puts "Finished."
