require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:test)

task :default => :test

# Load all rake tasks:
import(*Dir.glob('tasks/**/*.rake'))
