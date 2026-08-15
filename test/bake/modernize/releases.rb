# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "sus/fixtures/async/reactor_context"
require "sus/fixtures/temporary_directory_context"
require "bake/context"

describe "modernize:releases" do
	include Sus::Fixtures::Async::ReactorContext
	include Sus::Fixtures::TemporaryDirectoryContext
	
	let(:context) {Bake::Context.load}
	let(:task) {context.lookup("modernize:releases")}
	let(:recipe) {task.instance_variable_get(:@instance)}
	
	let(:bake_path) {File.join(root, "bake.rb")}
	let(:releases_md_path) {File.join(root, "releases.md")}
	let(:readme_path) {File.join(root, "readme.md")}
	
	it "updates the release project files" do
		File.write(readme_path, "# Example\n")
		
		mock(recipe) do |mock|
			mock.replace(:system) do |*arguments, chdir: nil|
				expect(arguments).to be == ["bundle", "add", "bake-releases", "--group", "maintenance"]
				expect(chdir).to be == root
				true
			end
			
			mock.replace(:update_bake) do |path|
				expect(path).to be == root
				File.write(bake_path, "# frozen_string_literal: true\n")
			end
		end
		
		task.call(root: root)
		
		expect(File.read(readme_path)).to be =~ /## Releases/
		expect(File.exist?(releases_md_path)).to be_truthy
		expect(File.exist?(bake_path)).to be_truthy
	end
	
	it "does not add releases to a readme that already has them" do
		content = "# Example\n\n## Releases\n\nExisting release notes.\n"
		File.write(readme_path, content)
		
		recipe.send(:update_releases, readme_path)
		
		expect(File.read(readme_path)).to be == content
	end
	
	it "adds releases before see also" do
		File.write(readme_path, "# Example\n\n## See Also\n\n- Other projects.\n")
		
		recipe.send(:update_releases, readme_path)
		
		result = File.read(readme_path)
		expect(result.index("## Releases")).to be < result.index("## See Also")
	end
	
	it "adds releases before contributing" do
		File.write(readme_path, "# Example\n\n## Contributing\n\n- Send patches.\n")
		
		recipe.send(:update_releases, readme_path)
		
		result = File.read(readme_path)
		expect(result.index("## Releases")).to be < result.index("## Contributing")
	end
	
	it "creates releases.md when it does not exist" do
		recipe.send(:update_releases_md, releases_md_path)
		
		expect(File.exist?(releases_md_path)).to be_truthy
		expect(File.read(releases_md_path)).to be =~ /Unreleased/
	end
	
	it "does not overwrite a releases.md that already exists" do
		existing_content = "# Releases\n\n## v1.0.0\n\n- Initial release\n"
		File.write(releases_md_path, existing_content)
		
		recipe.send(:update_releases_md, releases_md_path)
		
		expect(File.read(releases_md_path)).to be == existing_content
	end
	
	it "creates bake.rb from template when none exists" do
		recipe.send(:update_bake, root)
		
		expect(File.exist?(bake_path)).to be_truthy
		expect(File.read(bake_path)).to be =~ /after_gem_release/
	end
	
	it "merges release hooks into an existing bake.rb using AI" do
		existing = <<~RUBY
			# frozen_string_literal: true
			
			def after_gem_release_version_increment(version)
				context["utopia:project:update"].call
			end
		RUBY
		File.write(bake_path, existing)
		
		mock(Bake::Modernize) do |mock|
			mock.replace(:transform_file) do |path, instruction:, template:, validate:|
				expect(path).to be == bake_path
				expect(instruction).to be(:include?, "Merge the template")
				expect(template).to be(:include?, "def after_gem_release")
				
				updated = <<~RUBY
					# frozen_string_literal: true
					
					def after_gem_release_version_increment(version)
						context["utopia:project:update"].call
						context["releases:update"].call(version)
					end
					
					def after_gem_release(tag:, **options)
						context["releases:github:release"].call(tag)
					end
				RUBY
				expect(validate.call(updated)).to be_truthy
				File.write(path, updated)
			end
		end
		
		recipe.send(:update_bake, root)
		
		result = File.read(bake_path)
		
		# New release hook added:
		expect(result).to be =~ /def after_gem_release\b/
		# Existing call preserved:
		expect(result).to be =~ /utopia:project:update/
		# Missing call merged in from template:
		expect(result).to be =~ /releases:update/
	end
end
