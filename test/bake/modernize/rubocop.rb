# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "bake/context"
require "sus/fixtures/temporary_directory_context"

describe "modernize:rubocop" do
	include Sus::Fixtures::TemporaryDirectoryContext
	
	let(:context) {Bake::Context.load}
	let(:task) {context.lookup("modernize:rubocop")}
	let(:recipe) {task.instance_variable_get(:@instance)}
	let(:gems_path) {File.join(root, "gems.rb")}
	
	it "updates rubocop dependencies using the gem helpers" do
		File.write(gems_path, %{source "https://rubygems.org"\n})
		
		mock(Bake::Modernize::Gems) do |mock|
			mock.replace(:ensure_dependencies) do |path, names, group:, template:|
				expect(path).to be == gems_path
				expect(names).to be == ["rubocop", "rubocop-md", "rubocop-socketry"]
				expect(group).to be == :test
				expect(template).to be(:include?, %{gem "rubocop-socketry"})
			end
		end
		
		recipe.send(:update_rubocop_gems, root)
	end
	
	it "updates rubocop project files" do
		File.write(gems_path, %{source "https://rubygems.org"\n})
		
		mock(recipe) do |mock|
			mock.replace(:update_rubocop_gems) do |path|
				expect(path).to be == root
			end
			mock.replace(:system) do |*arguments, chdir: nil|
				expect(chdir).to be == root
				expect(arguments.first(2)).to be == ["bundle", arguments[1]]
			end
		end
		
		task.call(root: root)
		
		expect(File.exist?(File.join(root, ".rubocop.yml"))).to be_truthy
		expect(File.exist?(File.join(root, ".github", "workflows", "rubocop.yaml"))).to be_truthy
	end
end
