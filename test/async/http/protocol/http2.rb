# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2024, by Samuel Williams.

require 'async/http/protocol/http2'
require 'async/http/a_protocol'

describe Async::HTTP::Protocol::HTTP2 do
	it_behaves_like Async::HTTP::AProtocol
	
	with '#as_json' do
		include Sus::Fixtures::Async::HTTP::ServerContext
		let(:protocol) {subject}
		
		it "generates a JSON representation" do
			response = client.get("/")
			connection = response.connection
			
			expect(connection.as_json).to be == "#<Async::HTTP::Protocol::HTTP2::Client 1 requests, 0 active streams>"
		ensure
			response&.close
		end
		
		it "generates a JSON string" do
			response = client.get("/")
			connection = response.connection
			
			expect(JSON.dump(connection)).to be == connection.to_json
		ensure
			response&.close
		end
	end
	
	with 'server' do
		include Sus::Fixtures::Async::HTTP::ServerContext
		let(:protocol) {subject}
		
		with 'bad requests' do
			it "should fail with explicit authority" do
				expect do
					client.post("/", [[':authority', 'foo']])
				end.to raise_exception(Protocol::HTTP2::StreamError)
			end
		end
		
		with 'closed streams' do
			it 'should delete stream after response stream is closed' do
				response = client.get("/")
				connection = response.connection
				
				response.read
				
				expect(connection.streams).to be(:empty?)
			end
		end
		
		with 'host header' do
			let(:app) do
				Protocol::HTTP::Middleware.for do |request|
					Protocol::HTTP::Response[200, request.headers, ["Authority: #{request.authority.inspect}"]]
				end
			end
			
			def make_client(endpoint, **options)
				# We specify nil for the authority - it won't be sent.
				options[:authority] = nil
				super
			end
			
			it "should not send :authority header if host header is present" do
				response = client.post("/", [['host', 'foo']])
				
				expect(response.headers).to have_keys('host')
				expect(response.headers['host']).to be == 'foo'
				
				# TODO Should HTTP/2 respect host header?
				expect(response.read).to be == "Authority: nil"
			end
		end
		
		with 'stopping requests' do
			let(:notification) {Async::Notification.new}
			
			let(:app) do
				Protocol::HTTP::Middleware.for do |request|
					body = Async::HTTP::Body::Writable.new
					
					reactor.async do |task|
						begin
							100.times do |i|
								body.write("Chunk #{i}")
								task.sleep (0.01)
							end
						rescue
							# puts "Response generation failed: #{$!}"
						ensure
							body.close
							notification.signal
						end
					end
					
					Protocol::HTTP::Response[200, {}, body]
				end
			end
			
			let(:pool) {client.pool}
			
			it "should close stream without closing connection" do
				expect(pool).to be(:empty?)
				
				response = client.get("/")
				
				expect(pool).not.to be(:empty?)
				
				response.close
				
				notification.wait
				
				expect(response.stream.connection).to be(:reusable?)
			end
		end
	end
end
