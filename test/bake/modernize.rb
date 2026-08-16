# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2026, by Samuel Williams.

require "bake"
require "bake/context"
require "bake/modernize"
require "bake/modernize/git"
require "sus/fixtures/temporary_directory_context"

describe Bake::Modernize do
	include Sus::Fixtures::TemporaryDirectoryContext
	
	let(:context) {Bake::Context.load}
	
	it "has a version number" do
		expect(Bake::Modernize::VERSION).to be =~ /^\d+\.\d+\.\d+$/
	end

	it "updates the gemfile before configuring actions" do
		calls = []
		task = context.lookup("modernize")
		recipe = task.instance_variable_get(:@instance)
		
		mock(recipe) do |mock|
			mock.replace(:call) do |*tasks|
				calls.concat(tasks)
			end
		end
		
		task.call
		
		expect(calls.index("modernize:gemfile")).to be < calls.index("modernize:actions")
	end
	
	it "detects stale files when the destination exists" do
		source_path = File.join(root, "source.txt")
		destination_path = File.join(root, "destination.txt")
		
		File.write(source_path, "new")
		File.write(destination_path, "old")
		
		expect(Bake::Modernize.stale?(source_path, destination_path)).to be == true
	end
	
	it "returns the default branch outside a git repository" do
		expect(Bake::Modernize::Git.current_branch(root, default: "main")).to be == "main"
	end
	
	it "updates documentation after a version increment" do
		calls = []
		call_context = Object.new
		call_context.define_singleton_method(:[]) do |name|
			Object.new.tap do |callable|
				callable.define_singleton_method(:call) do |*arguments|
					calls << [name, arguments]
				end
			end
		end
		task = context.lookup("after_gem_release_version_increment")
		recipe = task.instance_variable_get(:@instance)
		
		mock(recipe) do |mock|
			mock.replace(:context){call_context}
		end
		
		task.call("1.2.3")
		
		expect(calls).to be == [
			["releases:update", ["1.2.3"]],
			["utopia:project:update", []],
		]
	end
	
	it "creates GitHub releases after gem release" do
		calls = []
		call_context = Object.new
		call_context.define_singleton_method(:[]) do |name|
			Object.new.tap do |callable|
				callable.define_singleton_method(:call) do |*arguments|
					calls << [name, arguments]
				end
			end
		end
		task = context.lookup("after_gem_release")
		recipe = task.instance_variable_get(:@instance)
		
		mock(recipe) do |mock|
			mock.replace(:context){call_context}
		end
		
		task.call(tag: "v1.2.3")
		
		expect(calls).to be == [["releases:github:release", ["v1.2.3"]]]
	end
end
