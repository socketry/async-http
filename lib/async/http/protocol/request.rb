# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2017-2023, by Samuel Williams.

require 'protocol/http/request'
require 'protocol/http/headers'

require_relative '../body/writable'

module Async
	module HTTP
		module Protocol
			# Failed to send the request. The request body has NOT been consumed (i.e. #read) and you should retry the request.
			class RequestFailed < StandardError
			end
			
			# This is generated by server protocols.
			class Request < ::Protocol::HTTP::Request
				def connection
					nil
				end
				
				def hijack?
					false
				end
				
				def write_interim_response(status, headers = nil)
				end
				
				def peer
					if connection = self.connection
						connection.peer
					end
				end
				
				def remote_address
					@remote_address ||= peer.remote_address
				end
				
				def remote_address= value
					@remote_address = value
				end
			end
		end
	end
end
