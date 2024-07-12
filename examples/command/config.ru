require 'async'
require 'async/queue'
require 'async/barrier'

class Multiplexer
	def initialize(stream)
		@stream = stream
		
		@streams = Hash.new{|h,k| h[k] = Async::Queue.new}
	end
	
	def write(name, data)
		@stream.puts name
		@stream.puts data.bytesize
		@stream.write data
		@stream.flush
	end
	
	def read
		if name = @stream.gets
			size = @stream.gets.to_i
			data = @stream.read(size)
			
			return name, data
		end
	end
	
	def run
		while message = self.read
			@streams[message.first] << message.last
		end
	end
	
	def queue(name)
		@streams[name]
	end
end

class Stream
	def initialize(multiplexer, name)
		@input, @output = IO.pipe
		@multiplexer = multiplexer
		@name = name
	end
	
	attr :input
	attr :output
	
	def write(data)
		@multiplexer.write(@name, data)
	end
	
	def read
		@multiplexer.queue(@name).dequeue
	end
	
	def sync_write
		@output.close
		
		while chunk = @input.readparial(1024)
			write(chunk)
		end
	end
	
	def sync_read
		@input.close
		
		while chunk = read
			@output.write(chunk)
		end
	end
end

run do |env|
	barrier = Async::Barrier.new
	
	body = proc do |stream|
		multiplexer = Multiplexer.new(stream)
		barrier.async do
			multiplexer.run
		end
		
		child_stdin = Stream.new(multiplexer, 'stdin')
		child_stdout = Stream.new(multiplexer, 'stdout')
		child_stderr = Stream.new(multiplexer, 'stderr')
		
		pid = Process.spawn('while true; do ls; sleep 1; done', in: child_stdin.input, out: child_stdout.output, err: child_stderr.output)
		
		barrier.async do
			child_stdin.sync_read
		end
		
		barrier.async do
			child_stdout.sync_write
		end
		
		barrier.async do
			child_stderr.sync_write
		end
		
		Process.wait(pid)
		
		barrier.wait
	ensure
		stream.close
		if pid
			Process.kill(:KILL, pid)
			Process.wait(pid)
		end
	end
	
	[200, {}, body]
end
