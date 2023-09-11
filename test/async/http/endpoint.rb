# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2023, by Samuel Williams.
# Copyright, 2021-2022, by Adam Daniels.

require 'async/http/endpoint'

RSpec.describe Async::HTTP::Endpoint do
	it "should fail to parse relative url" do
		expect{
			described_class.parse("/foo/bar")
		}.to raise_error(ArgumentError, /absolute/)
	end
	
	describe '#port' do
		let(:url_string) {"https://localhost:9292"}
		
		it "extracts port from URL" do
			endpoint = Async::HTTP::Endpoint.parse(url_string)
			
			expect(endpoint.port).to eq 9292
		end
		
		it "extracts port from options" do
			endpoint = Async::HTTP::Endpoint.parse(url_string, port: 9000)
			
			expect(endpoint.port).to eq 9000
		end
	end
	
	describe '#hostname' do
		describe Async::HTTP::Endpoint.parse("https://127.0.0.1:9292") do
			it {is_expected.to have_attributes(hostname: '127.0.0.1')}
			
			it "should be connecting to 127.0.0.1" do
				expect(subject.endpoint).to be_a Async::IO::SSLEndpoint
				expect(subject.endpoint).to have_attributes(hostname: '127.0.0.1')
				expect(subject.endpoint.endpoint).to have_attributes(hostname: '127.0.0.1')
			end
		end
		
		describe Async::HTTP::Endpoint.parse("https://127.0.0.1:9292", hostname: 'localhost') do
			it {is_expected.to have_attributes(hostname: 'localhost')}
			it {is_expected.to_not be_localhost}
			
			it "should be connecting to localhost" do
				expect(subject.endpoint).to be_a Async::IO::SSLEndpoint
				expect(subject.endpoint).to have_attributes(hostname: '127.0.0.1')
				expect(subject.endpoint.endpoint).to have_attributes(hostname: 'localhost')
			end
		end
	end
	
	describe '.for' do
		context Async::HTTP::Endpoint.for("http", "localhost") do
			it {is_expected.to have_attributes(scheme: "http", hostname: "localhost", path: "/")}
			it {is_expected.to_not be_secure}
		end

		context Async::HTTP::Endpoint.for("http", "localhost", "/foo") do
			it {is_expected.to have_attributes(scheme: "http", hostname: "localhost", path: "/foo")}
		end
	end
	
	describe '#secure?' do
		subject {Async::HTTP::Endpoint.parse(description)}
		
		context 'http://localhost' do
			it { is_expected.to_not be_secure }
		end
		
		context 'https://localhost' do
			it { is_expected.to be_secure }
		end
		
		context 'with scheme: https' do
			subject {Async::HTTP::Endpoint.parse("http://localhost", scheme: 'https')}
			
			it { is_expected.to be_secure }
		end
	end
	
	describe '#localhost?' do
		subject {Async::HTTP::Endpoint.parse(description)}
		
		context 'http://localhost' do
			it { is_expected.to be_localhost }
		end
		
		context 'http://hello.localhost' do
			it { is_expected.to be_localhost }
		end
		
		context 'http://localhost.' do
			it { is_expected.to be_localhost }
		end
		
		context 'http://hello.localhost.' do
			it { is_expected.to be_localhost }
		end
		
		context 'http://localhost.com' do
			it { is_expected.to_not be_localhost }
		end
	end
	
	describe '#path' do
		it "can normal urls" do
			endpoint = Async::HTTP::Endpoint.parse("http://foo.com/bar?baz")
			expect(endpoint.path).to be == "/bar?baz"
		end
		
		it "can handle websocket urls" do
			endpoint = Async::HTTP::Endpoint.parse("wss://foo.com/bar?baz")
			expect(endpoint.path).to be == "/bar?baz"
		end
	end
end

RSpec.describe "http://www.google.com/search" do
	let(:endpoint) {Async::HTTP::Endpoint.parse(subject)}
	
	it "should be valid endpoint" do
		expect{endpoint}.to_not raise_error
	end
	
	it "should select the correct protocol" do
		expect(endpoint.protocol).to be Async::HTTP::Protocol::HTTP1
	end
	
	it "should parse the correct hostname" do
		expect(endpoint.hostname).to be == "www.google.com"
	end
	
	it "should not be equal if path is different" do
		other = Async::HTTP::Endpoint.parse('http://www.google.com/search?q=ruby')
		expect(endpoint).to_not be_eql other
	end
end
