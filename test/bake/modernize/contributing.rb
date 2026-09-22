# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "bake/context"
require "sus/fixtures/isolated_ruby_context"
require "sus/fixtures/temporary_directory_context"

describe "modernize:contributing" do
	include Sus::Fixtures::TemporaryDirectoryContext
	include Sus::Fixtures::IsolatedRubyContext
	
	let(:recipe) {Bake::Context.load.lookup("modernize:contributing").instance}
	let(:readme_path) {File.join(root, "readme.md")}
	
	before do
		File.write(readme_path, "# Example\n\n## Contributing\n\nExisting instructions.\n")
	end
	
	it "documents release PRs when the project uses bake-gem-github" do
		File.write(File.join(root, "gems.rb"), 'gem "bake-gem-github"')
		
		recipe.send(:update_contributing, readme_path)
		
		expect(File.read(readme_path)).to be(:include?, "bake gem:github:release:patch")
		expect(File.read(readme_path)).to be(:include?, "https://github.com/socketry/bake-gem-github")
	end
	
	it "keeps local release instructions for other projects" do
		File.write(File.join(root, "gems.rb"), 'gem "bake-gem"')
		
		recipe.send(:update_contributing, readme_path)
		
		expect(File.read(readme_path)).to be(:include?, "bake gem:release:patch")
		expect(File.read(readme_path)).not.to be(:include?, "gem:github:release")
	end
	
	it "updates the project from its working directory" do
		File.write(File.join(root, "conduct.md"), "Old guidelines.\n")
		File.write(File.join(root, "gems.rb"), 'gem "bake-gem-github"')
		
		isolated_ruby(<<~RUBY, chdir: root)
			require "bake/context"
			Bake::Context.load.call("modernize:contributing")
			nil
		RUBY
		
		expect(File).not.to be(:exist?, File.join(root, "conduct.md"))
		expect(File.read(readme_path)).to be(:include?, "gem:github:release:patch")
	end
end
