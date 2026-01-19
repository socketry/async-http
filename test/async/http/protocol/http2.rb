# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2025, by Samuel Williams.

require "async/http/protocol/http2"
require "async/http/a_protocol"
require "async/promise"

describe Async::HTTP::Protocol::HTTP2 do
	it_behaves_like Async::HTTP::AProtocol
	
	with "#as_json" do
		include Sus::Fixtures::Async::HTTP::ServerContext
		let(:protocol) {subject}
		
		it "generates a JSON representation" do
			response = client.get("/")
			connection = response.connection
			
			expect(connection.as_json).to be =~ /#<Async::HTTP::Protocol::HTTP2::Client \d+ active streams>/
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
	
	with "server" do
		include Sus::Fixtures::Async::HTTP::ServerContext
		let(:protocol) {subject}
		
		with "bad requests" do
			it "should fail with explicit authority" do
				expect do
					client.post("/", [[":authority", "foo"]])
				end.to raise_exception(Protocol::HTTP2::StreamError)
			end
			
			with "a bad request header" do
				let(:app) do
					Protocol::HTTP::Middleware.for do
						@app_called = true
						Protocol::HTTP::Response[200]
					end
				end
				
				it "keeps the connection reusable" do
					@app_called = false
					response = client.get("/", [["range", "bytes=4-1"]])
					
					expect(response.status).to be == 400
					expect(@app_called).to be == false
					
					response.finish
					response = client.get("/")
					
					expect(response.status).to be == 200
					expect(@app_called).to be == true
				ensure
					response&.close
				end
				
				it "does not send response data for HEAD" do
					response = client.head("/", [["range", "bytes=4-1"]])
					
					expect(response.status).to be == 400
					expect(response.body.length).to be_nil
					expect(response.read).to be_nil
				ensure
					response&.close
				end
				
				it "terminates an unfinished request body" do
					body = Async::HTTP::Body::Writable.new
					response = client.post("/", [["range", "bytes=4-1"]], body)
					connection = response.connection
					
					expect(response.status).to be == 400
					expect(response.read).to be == "Protocol::HTTP::Header::Range::ParseError"
					expect(response.stream).to be(:closed?)
					expect(connection.streams).to be(:empty?)
					expect(connection).to be(:reusable?)
				ensure
					body&.close
					response&.close
				end
			end
			
			with "a malformed request" do
				it "prioritizes protocol validation over bad request handling" do
					client.pool.acquire do |connection|
						response = connection.create_response
						response.stream.send_headers([
							[":method", "GET"],
							[":path", "/"],
							["range", "bytes=4-1"],
						], ::Protocol::HTTP2::END_STREAM)
						
						expect do
							connection.read_response(response)
						end.to raise_exception(Protocol::HTTP2::StreamError).and(
							have_attributes(code: be == Protocol::HTTP2::Error::STREAM_CLOSED)
						)
					end
				end
			end
		end
		
		with "closed streams" do
			it "should delete stream after response stream is closed" do
				response = client.get("/")
				connection = response.connection
				
				response.read
				
				expect(connection.streams).to be(:empty?)
			end
		end
		
		with "host header" do
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
				response = client.post("/", [["host", "foo"]])
				
				expect(response.headers).to have_keys("host")
				expect(response.headers["host"]).to be == "foo"
				
				# TODO Should HTTP/2 respect host header?
				expect(response.read).to be == "Authority: nil"
			end
		end
		
		with "stopping requests" do
			let(:finished) {Async::Promise.new}
			
			let(:app) do
				Protocol::HTTP::Middleware.for do |request|
					body = Async::HTTP::Body::Writable.new
					
					reactor.async do |task|
						begin
							1000.times do |i|
								body.write("Chunk #{i}")
								sleep (0.01)
							end
						rescue
							# puts "Response generation failed: #{$!}"
						ensure
							body.close
							finished.resolve(true)
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
				
				finished.wait(timeout: 1)
				
				expect(response.stream.connection).to be(:reusable?)
			end
		end
	end
end
