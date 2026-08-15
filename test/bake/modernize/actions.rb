# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "bake/context"
require "async/ollama"
require "sus/fixtures/temporary_directory_context"

describe "modernize:actions" do
	include Sus::Fixtures::TemporaryDirectoryContext
	
	let(:context) {Bake::Context.load}
	let(:task) {context.lookup("modernize:actions")}
	let(:recipe) {task.instance_variable_get(:@instance)}
	
	it "includes the external test workflow when config/external.yaml exists" do
		FileUtils.mkdir_p(File.join(root, "config"))
		File.write(File.join(root, "config", "external.yaml"), "---\n")
		gems = <<~RUBY
			source "https://rubygems.org"
			
			group :test do
				gem "bake-test"
			end
		RUBY
		File.write(File.join(root, "gems.rb"), gems)
		
		mock(Async::Ollama::Transform) do |mock|
			mock.replace(:call) do |content, model:, instruction:, template:|
				expect(content).to be == gems
				expect(model).to be == "qwen3-coder:latest"
				expect(instruction).to be(:include?, "included in the `test` group")
				expect(template).to be(:include?, %{gem "bake-test-external"})
				
				gems.sub(%{	gem "bake-test"\n}, %{\tgem "bake-test"\n\tgem "bake-test-external"\n})
			end
		end
		
		mock(recipe) do |mock|
			mock.replace(:system) {}
		end
		
		task.call(root: root)
		
		external_workflow_path = File.join(root, ".github", "workflows", "test-external.yaml")
		expect(File.exist?(external_workflow_path)).to be_truthy
		
		expect(File.read(File.join(root, "gems.rb"))).to be(:include?, %{gem "bake-test-external"})
	end
	
	it "removes the external test workflow when config/external.yaml does not exist" do
		FileUtils.mkdir_p(File.join(root, ".github", "workflows"))
		File.write(File.join(root, ".github", "workflows", "test-external.yaml"), "name: Test External\n")
		gems = <<~RUBY
			source "https://rubygems.org"
			
			group :test do
				gem "bake-test"
				gem "bake-test-external"
			end
		RUBY
		File.write(File.join(root, "gems.rb"), gems)
		
		mock(Async::Ollama::Transform) do |mock|
			mock.replace(:call) do |content, model:, instruction:, template:|
				expect(content).to be == gems
				expect(model).to be == "qwen3-coder:latest"
				expect(instruction).to be(:include?, "Remove the `bake-test-external` gem")
				expect(template).not.to be(:include?, %{gem "bake-test-external"})
				
				gems.sub(%{	gem "bake-test-external"\n}, "")
			end
		end
		
		mock(recipe) do |mock|
			mock.replace(:system) {}
		end
		
		task.call(root: root)
		
		external_workflow_path = File.join(root, ".github", "workflows", "test-external.yaml")
		expect(File.exist?(external_workflow_path)).to be_falsey
		
		expect(File.read(File.join(root, "gems.rb"))).not.to be(:include?, %{gem "bake-test-external"})
	end
end
