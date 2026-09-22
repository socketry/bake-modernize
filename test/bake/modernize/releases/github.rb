# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "bake/context"
require "sus/fixtures/temporary_directory_context"

describe "modernize:releases:github" do
	include Sus::Fixtures::TemporaryDirectoryContext
	
	let(:task) {Bake::Context.load.lookup("modernize:releases:github")}
	let(:recipe) {task.instance}
	let(:gems_path) {File.join(root, "gems.rb")}
	let(:bake_path) {File.join(root, "bake.rb")}
	
	before do
		File.write(File.join(root, "readme.md"), "# Example\n")
	end
	
	it "replaces bake-gem and generates preparation hooks without publishing hooks" do
		File.write(gems_path, "gem \"bake-gem\"\n")
		calls = []
		
		mock(recipe) do |mock|
			mock.replace(:system) do |environment, *arguments, **options|
				expect(environment).not.to have_keys("BUNDLE_GEMFILE")
				expect(options).to be == {chdir: root, unsetenv_others: true, exception: true}
				calls << arguments
				case arguments
				when ["bundle", "add", "bake-gem-github", "--group", "maintenance"]
					File.write(gems_path, "gem \"bake-gem-github\"\n", mode: "a")
				when ["bundle", "remove", "bake-gem"]
					File.write(gems_path, File.read(gems_path).sub("gem \"bake-gem\"\n", ""))
				end
				true
			end
		end
		
		task.call(root: root)
		
		expect(calls).to be == [
			["bundle", "add", "bake-gem-github", "--group", "maintenance"],
			["bundle", "remove", "bake-gem"],
		]
		expect(Bake::Modernize.gem_dependencies(root)).to be == ["bake-gem-github"]
		expect(File.read(bake_path)).to be(:include?, "def after_gem_release_version_increment")
		expect(File.read(bake_path)).not.to be =~ /def after_gem_release\(/
		expect(File.read(File.join(root, "releases.md"))).to be(:include?, "Unreleased")
	end
	
	it "does not reinstall an existing dependency or remove absent bake-gem" do
		File.write(gems_path, 'gem "bake-gem-github", "~> 0.4.0"')
		mock(recipe) do |mock|
			mock.replace(:system){raise "Unexpected dependency change."}
		end
		
		task.call(root: root)
		
		expect(File.read(gems_path)).to be == 'gem "bake-gem-github", "~> 0.4.0"'
		expect(File.read(bake_path)).not.to be =~ /def after_gem_release\(/
	end
	
	it "stops before removing bake-gem or changing hooks when installation fails" do
		File.write(gems_path, 'gem "bake-gem"')
		mock(recipe) do |mock|
			mock.replace(:system) do |environment, *arguments, **options|
				expect(arguments).to be == ["bundle", "add", "bake-gem-github", "--group", "maintenance"]
				raise "Installation failed."
			end
		end
		
		expect{task.call(root: root)}.to raise_exception(RuntimeError, message: be == "Installation failed.")
		expect(File.read(gems_path)).to be == 'gem "bake-gem"'
		expect(File).not.to be(:exist?, bake_path)
	end
end
