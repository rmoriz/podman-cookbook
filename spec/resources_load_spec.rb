# frozen_string_literal: true

require 'English'
require 'spec_helper'

# Partial resolution is relative to the file that calls `use`. Chef 19 loads
# resource files under a synthetic source name, so a `use` inside a partial
# (recursive use) resolves against chef's own lib directory instead of the
# cookbook. Compile every resource in a child process, the same way, so the
# recursion cannot come back unnoticed.
describe 'resource files' do
  it 'compile with the cookbook as their source' do
    script = <<~RUBY
      require 'chef'
      Dir['libraries/**/*.rb'].sort.each { |file| load File.expand_path(file) }
      Dir['resources/*.rb'].sort.each do |file|
        Class.new(Chef::Resource).class_eval(File.read(file), File.expand_path(file), 1)
      end
    RUBY

    output = IO.popen([RbConfig.ruby, '-e', script], err: %i(child out), &:read)

    expect($CHILD_STATUS).to be_success, output
  end
end
