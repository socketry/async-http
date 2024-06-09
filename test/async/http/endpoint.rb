# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2024, by Samuel Williams.
# Copyright, 2021-2022, by Adam Daniels.

require 'async/http/endpoint'

describe Async::HTTP::Endpoint do
	it "should fail to parse relative url" do
		expect do
			subject.parse("/foo/bar")
		end.to raise_exception(ArgumentError, message: be =~ /absolute/)
	end
	
	with '#port' do
		let(:url_string) {"https://localhost:9292"}
		
		it "extracts port from URL" do
			endpoint = Async::HTTP::Endpoint.parse(url_string)
			
			expect(endpoint).to have_attributes(port: be == 9292)
		end
		
		it "extracts port from options" do
			endpoint = Async::HTTP::Endpoint.parse(url_string, port: 9000)
			
			expect(endpoint).to have_attributes(port: be == 9000)
		end
	end
	
	with '#hostname' do
		describe Async::HTTP::Endpoint.parse("https://127.0.0.1:9292") do
			it 'has correct hostname' do
				expect(subject).to have_attributes(hostname: be == '127.0.0.1')
			end
			
			it "should be connecting to 127.0.0.1" do
				expect(subject.endpoint).to be_a ::IO::Endpoint::SSLEndpoint
				expect(subject.endpoint).to have_attributes(hostname: be == '127.0.0.1')
				expect(subject.endpoint.endpoint).to have_attributes(hostname: be == '127.0.0.1')
			end
		end
		
		describe Async::HTTP::Endpoint.parse("https://127.0.0.1:9292", hostname: 'localhost') do
			it 'has correct hostname' do
				expect(subject).to have_attributes(hostname: be == 'localhost')
				expect(subject).not.to be(:localhost?)
			end
			
			it "should be connecting to localhost" do
				expect(subject.endpoint).to be_a ::IO::Endpoint::SSLEndpoint
				expect(subject.endpoint).to have_attributes(hostname: be == '127.0.0.1')
				expect(subject.endpoint.endpoint).to have_attributes(hostname: be == 'localhost')
			end
		end
	end
	
	with '.for' do
		describe Async::HTTP::Endpoint.for("http", "localhost") do
			it "should have correct attributes" do
				expect(subject).to have_attributes(
					scheme: be == "http",
					hostname: be == "localhost",
					path: be == "/"
				)
				
				expect(subject).not.to be(:secure?)
			end
		end

		describe Async::HTTP::Endpoint.for("http", "localhost", "/foo") do
			it "should have correct attributes" do
				expect(subject).to have_attributes(
					scheme: be == "http",
					hostname: be == "localhost",
					path: be == "/foo"
				)
				
				expect(subject).not.to be(:secure?)
			end
		end
	end
	
	with '#secure?' do
		describe Async::HTTP::Endpoint.parse("http://localhost") do
			it "should not be secure" do
				expect(subject).not.to be(:secure?)
			end
		end
		
		describe Async::HTTP::Endpoint.parse("https://localhost") do
			it "should be secure" do
				expect(subject).to be(:secure?)
			end
		end
		
		with 'scheme: https' do
			describe Async::HTTP::Endpoint.parse("http://localhost", scheme: 'https') do
				it "should be secure" do
					expect(subject).to be(:secure?)
				end
			end
		end
	end
	
	with '#localhost?' do
		describe Async::HTTP::Endpoint.parse("http://localhost") do
			it "should be localhost" do
				expect(subject).to be(:localhost?)
			end
		end
		
		describe Async::HTTP::Endpoint.parse("http://hello.localhost") do
			it "should be localhost" do
				expect(subject).to be(:localhost?)
			end
		end
		
		describe Async::HTTP::Endpoint.parse("http://localhost.") do
			it "should be localhost" do
				expect(subject).to be(:localhost?)
			end
		end
		
		describe Async::HTTP::Endpoint.parse("http://hello.localhost.") do
			it "should be localhost" do
				expect(subject).to be(:localhost?)
			end
		end
		
		describe Async::HTTP::Endpoint.parse("http://localhost.com") do
			it "should not be localhost" do
				expect(subject).not.to be(:localhost?)
			end
		end
	end
	
	with '#path' do
		describe Async::HTTP::Endpoint.parse("http://foo.com/bar?baz") do
			it "should have correct path" do
				expect(subject).to have_attributes(path: be == "/bar?baz")
			end
		end
		
		with 'websocket scheme' do
			describe Async::HTTP::Endpoint.parse("wss://foo.com/bar?baz") do
				it "should have correct path" do
					expect(subject).to have_attributes(path: be == "/bar?baz")
				end
			end
		end
	end
end

describe Async::HTTP::Endpoint.parse("http://www.google.com/search") do
	it "should select the correct protocol" do
		expect(subject.protocol).to be == Async::HTTP::Protocol::HTTP
	end
	
	it "should parse the correct hostname" do
		expect(subject).to have_attributes(
			scheme: be == "http",
			hostname: be == "www.google.com",
			path: be == "/search"
		)
	end
	
	it "should not be equal if path is different" do
		other = Async::HTTP::Endpoint.parse('http://www.google.com/search?q=ruby')
		expect(subject).not.to be == other
		expect(subject).not.to be(:eql?, other)
	end
end
