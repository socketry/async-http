
require 'async/http/server'
require 'async/http/client'

require 'async/io/ssl_socket'

require 'async/rspec/reactor'
require 'async/rspec/ssl'

RSpec.describe Async::HTTP::Server do
	include_context Async::RSpec::Reactor
	include_context Async::RSpec::SSL::ValidCertificate

	describe "application layer protocol negotiation" do
		let(:server_context) do
			OpenSSL::SSL::SSLContext.new.tap do |context|
				context.cert = certificate

				context.alpn_select_cb = lambda do |protocols|
					protocols.last
				end

				context.key = key
			end
		end

		let(:client_context) do
			OpenSSL::SSL::SSLContext.new.tap do |context|
				context.cert_store = certificate_store

				context.alpn_protocols = ["http/1.0", "http/1.1", "h2"]

				context.verify_mode = OpenSSL::SSL::VERIFY_PEER
			end
		end

		# Shared port for localhost network tests.
		let(:endpoint) {Async::IO::Endpoint.tcp("localhost", 6779, reuse_port: true)}
		let(:server_endpoint) {Async::IO::SecureEndpoint.new(endpoint, ssl_context: server_context)}
		let(:client_endpoint) {Async::IO::SecureEndpoint.new(endpoint, ssl_context: client_context)}

		it "client can get a resource via https" do
			server = Async::HTTP::Server.new([server_endpoint], Async::HTTP::Protocol::HTTPS)
			client = Async::HTTP::Client.new([client_endpoint], Async::HTTP::Protocol::HTTPS)

			Async::Reactor.run do |task|
				server_task = task.async do
					server.run
				end

				response = client.get("/")

				expect(response).to be_success
				expect(response.body).to be == "Hello World"
				server_task.stop
			end
		end
	end
end
