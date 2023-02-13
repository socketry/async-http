# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2023, by Samuel Williams.

require 'trenni/template'

require 'async'
require 'async/http/body/writable'

# The template, using inline text. The sleep could be anything - database query, HTTP request, redis, etc.
buffer = Trenni::Buffer.new(<<-EOF)
The "\#{self[:count]} bottles of \#{self[:drink]} on the wall" song!

<?r self[:count].downto(1) do |index| ?>
	\#{index} bottles of \#{self[:drink]} on the wall,
	\#{index} bottles of \#{self[:drink]},
	take one down, and pass it around,
	\#{index - 1} bottles of \#{self[:drink]} on the wall.
	
	<?r Async::Task.current.sleep(1) ?>
<?r end ?>
EOF

template = Trenni::Template.new(buffer)

Async do
	body = Async::HTTP::Body::Writable.new

	generator = Async do
		template.to_string({count: 100, drink: 'coffee'}, body)
	end

	while chunk = body.read
		$stdout.write chunk
	end
	
	generator.wait
end.wait
