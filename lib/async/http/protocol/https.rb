# Copyright, 2017, by Samuel G. D. Williams. <http://www.codeotaku.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require_relative 'http10'
require_relative 'http11'
require_relative 'http2'

module Async
  module HTTP
    module Protocol
      # A server that supports both HTTP1.0 and HTTP1.1 semantics by detecting the version of the request.
      module HTTPS
        HANDLERS = {
          "http/1.0" => HTTP10,
          "http/1.1" => HTTP11,
          "h2" => HTTP2,
        }

        def self.new(stream, mode)
          # alpn_protocol is only available if openssl v1.0.2+
          name = stream.io.alpn_protocol

          if name and protocol = HANDLERS[name]
            return protocol.new(stream, mode)
          else
            return HTTP2.new(stream, mode)
          end
        end
      end
    end
  end
end
