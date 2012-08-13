require 'rubygems'
require 'bundler'
Bundler.require

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new("spec") do |spec|
  spec.pattern = "spec/**/*_spec.rb"
end

def run(cmd)
  exit(1) unless Kernel.system(cmd)
end

desc 'Run specs for each gemfile'
task :all_specs do
  Dir['gemfiles/*.gemfile'].each do |gemfile|
    ENV['BUNDLE_GEMFILE'] = gemfile

    puts "Running with #{gemfile}"
    run("bundle") unless File.exist?("#{gemfile}.lock")
    run("bundle exec rake spec")
    puts ""
  end
end

task :default => :all_specs
