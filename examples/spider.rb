
require 'async/await'

require_relative '../lib/async/http/client'
require '../lib/async/http/url_endpoint'
require '../lib/async/http/protocol/https'

require 'trenni/sanitize'
require 'set'

# Async.logger.level = Logger::DEBUG

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

class << self
	include Async::Await
	
	async def fetch(url, depth = 4, fetched = Set.new)
		return if fetched.include? url
		fetched << url
		
		endpoint = Async::HTTP::URLEndpoint.new(url)
		client = Async::HTTP::Client.new([endpoint], endpoint.secure? ? Async::HTTP::Protocol::HTTPS : Async::HTTP::Protocol::HTTP11)
		
		request_uri = endpoint.specification.request_uri
		puts "GET #{url} (depth = #{depth})"
		
		response = client.get(request_uri, {
			#'Host' => endpoint.specification.hostname,
			':authority' => endpoint.specification.hostname,
			'accept' => '*/*',
			# 'accept-encoding' => 'gzip, deflate',
			'user-agent' => 'nghttp2/1.30.0',
		})
		
		if response.status >= 300 && response.status < 400
			location = url + response.headers['location']
			puts "Following redirect to #{location}"
			return fetch(location, depth-1, fetched)
		end
		
		content_type = response.headers['content-type']
		unless content_type&.start_with? 'text/html'
			puts "Unsupported content type: #{response.headers['content-type']}"
			return
		end
		
		base = endpoint.specification
		
		begin
			html = HTML.parse(response.body)
		rescue
			puts $!
			return
		end
		
		if html.base
			base = base + html.base
		end
		
		return if depth == 0
		
		puts "Resolving urls relative to #{base.inspect}"
		
		html.links.each do |href|
			begin
				full_url = base + href
				
				fetch(full_url, depth - 1, fetched) if full_url.kind_of? URI::HTTP
			rescue ArgumentError, URI::InvalidURIError
				puts "Could not fetch #{href}, relative to #{base}."
			end
		end
	rescue StandardError
		puts $!
	end
end

fetch(URI.parse("https://www.codeotaku.com"))
puts "Finished."
