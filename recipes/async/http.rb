
recipe :fetch, description: "Fetch the specified URL and print the response." do |method:, url:|
	require 'async/http/internet'
	require 'kernel/sync'
	
	terminal = Console::Terminal.for($stdout)
	terminal[:request] = terminal.style(:blue, nil, :bold)
	terminal[:response] = terminal.style(:green, nil, :bold)
	terminal[:length] = terminal.style(nil, nil, :bold)
	
	terminal[:key] = terminal.style(nil, nil, :bold)
	
	terminal[:chunk_0] = terminal.style(:blue)
	terminal[:chunk_1] = terminal.style(:cyan)
	
	align = 20
	
	format_body = proc do |body, terminal|
		if body
			if length = body.length
				terminal.print(:body, "body with length", :length, length, "B")
			else
				terminal.print(:body, "body without length")
			end
		else
			terminal.print(:body, "no body")
		end
	end.curry
	
	Sync do
		internet = Async::HTTP::Internet.new
		
		response = internet.send(method.downcase.to_sym, url)
		
		terminal.print_line(
			:request, method.rjust(align), :reset, ": ", url
		)
		
		terminal.print_line(
			:response, "version".rjust(align), :reset, ": ", response.version
		)
		
		terminal.print_line(
			:response, "status".rjust(align), :reset, ": ", response.status,
		)
		
		terminal.print_line(
			:response, "body".rjust(align), :reset, ": ", format_body[response.body],
		)
		
		response.headers.each do |key, value|
			terminal.print_line(
				:key, key.rjust(align), :reset, ": ", :value, value.inspect
			)
		end
		
		if body = response.body
			index = 0
			style = [:chunk_0, :chunk_1]
			response.body.each do |chunk|
				terminal.print(style[index % 2], chunk)
				index += 1
			end
		end
		
		response.finish
		internet.close
	end
end

recipe :get, description: "GET the specified URL and print the response." do |url:|
	call :fetch, "method=GET", "url=#{url}"
end

recipe :head, description: "HEAD the specified URL and print the response." do |url:|
	call :fetch, "method=HEAD", "url=#{url}"
end

