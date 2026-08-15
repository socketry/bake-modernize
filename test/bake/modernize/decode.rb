# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "bake/context"
require "sus/fixtures/temporary_directory_context"

describe "modernize:decode" do
	include Sus::Fixtures::TemporaryDirectoryContext
	
	let(:context) {Bake::Context.load}
	let(:task) {context.lookup("modernize:decode")}
	let(:recipe) {task.instance_variable_get(:@instance)}
	let(:gems_path) {File.join(root, "gems.rb")}
	
	it "moves decode dependency using a validated transform" do
		existing = <<~RUBY
			source "https://rubygems.org"
			
			group :test do
				gem "decode"
			end
		RUBY
		updated = <<~RUBY
			source "https://rubygems.org"
			
			group :maintenance, optional: true do
				gem "decode"
			end
		RUBY
		File.write(gems_path, existing)
		
		mock(Bake::Modernize) do |mock|
			mock.replace(:transform_file) do |path, instruction:, template:, validate:|
				expect(path).to be == gems_path
				expect(instruction).to be(:include?, "Move the `decode` gem")
				expect(template).to be(:include?, %{gem "decode"})
				expect(validate.call(updated)).to be_truthy
				File.write(path, updated)
			end
		end
		
		task.call(root: root)
		
		expect(File.read(gems_path)).to be == updated
	end
	
	it "does nothing without gems.rb" do
		task.call(root: root)
		
		expect(File.exist?(gems_path)).to be_falsey
	end
end
