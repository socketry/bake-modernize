# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "bake/context"
require "bake/modernize"
require "sus/fixtures/temporary_directory_context"
require "tmpdir"

describe "modernize:gemspec" do
	include Sus::Fixtures::TemporaryDirectoryContext
	
	let(:context) {Bake::Context.load}
	let(:task) {context.lookup("modernize:gemspec")}
	let(:update_task) {context.lookup("modernize:gemspec:update")}
	let(:recipe) {update_task.instance}
	let(:gemspec_path) {File.join(root, "example.gemspec")}
	let(:output) {StringIO.new}
	
	def write_project(metadata = nil, branch: "main")
		version_path = File.join(root, "lib", "example", "version.rb")
		FileUtils.mkdir_p(File.dirname(version_path))
		File.write(version_path, <<~RUBY)
			module Example
				VERSION = "1.0.0"
			end
		RUBY
		
		metadata = {
			"documentation_uri" => "https://socketry.github.io/example/",
			"funding_uri" => "https://github.com/sponsors/socketry/",
			"source_code_uri" => "https://github.com/socketry/example.git",
		}.merge(metadata || {})
		
		File.write(gemspec_path, <<~RUBY)
			# frozen_string_literal: true
			
			Gem::Specification.new do |spec|
				spec.name = "example"
				spec.version = "1.0.0"
				
				spec.summary = "An example gem."
				spec.authors = ["Samuel Williams"]
				spec.license = "MIT"
				
				spec.homepage = "https://github.com/socketry/example"
				
				spec.metadata = #{metadata.inspect}
				
				spec.files = Dir["lib/**/*.rb", base: __dir__]
			end
		RUBY
		
		repository = Rugged::Repository.init_at(root)
		repository.index.add_all
		repository.index.write
		
		signature = {name: "Samuel Williams", email: "samuel@example.com", time: Time.now}
		tree = repository.index.write_tree(repository)
		
		commit_id = Rugged::Commit.create(
			repository,
			message: "Initial commit.",
			author: signature,
			committer: signature,
			parents: [],
			tree: tree,
			update_ref: "HEAD",
		)
		
		unless repository.head.name == "refs/heads/#{branch}"
			repository.branches.create(branch, commit_id)
			repository.head = "refs/heads/#{branch}"
		end
	end
	
	def update_gemspec
		update_task.call(path: gemspec_path, output: output)
		
		return output.string
	end
	
	def build_spec(name: "example", homepage: "https://github.com/socketry/example")
		Gem::Specification.new do |spec|
			spec.name = name
			spec.version = "1.0.0"
			spec.summary = "An example gem."
			spec.license = "MIT"
			spec.homepage = homepage
			spec.files = []
			spec.loaded_from = gemspec_path
		end
	end
	
	it "adds GitHub bug tracker metadata" do
		write_project
		
		result = update_gemspec
		
		expect(result).to be(:include?, %("bug_tracker_uri" => "https://github.com/socketry/example/issues"))
	end
	
	it "adds changelog metadata using the current branch when releases.md exists" do
		write_project(branch: "next")
		File.write(File.join(root, "releases.md"), "# Releases\n")
		
		result = update_gemspec
		
		expect(result).to be(:include?, %("changelog_uri" => "https://github.com/socketry/example/blob/next/releases.md"))
	end
	
	it "does not add changelog metadata without releases.md" do
		write_project
		
		result = update_gemspec
		
		expect(result).not.to be(:include?, "changelog_uri")
	end
	
	it "preserves existing metadata" do
		write_project({
			"bug_tracker_uri" => "https://example.com/issues",
			"changelog_uri" => "https://example.com/changelog",
		})
		
		result = update_gemspec
		
		expect(result).to be(:include?, %("bug_tracker_uri" => "https://example.com/issues"))
		expect(result).to be(:include?, %("changelog_uri" => "https://example.com/changelog"))
	end
	
	it "rewrites the default gemspec" do
		write_project
		
		mock(recipe) do |mock|
			mock.replace(:default_gemspec_path){gemspec_path}
		end
		
		task.call
		
		expect(File.read(gemspec_path)).to be(:include?, "spec.version = Example::VERSION")
	end
	
	it "emits optional gemspec fields" do
		write_project
		FileUtils.mkdir_p(File.join(root, "exe"))
		FileUtils.mkdir_p(File.join(root, "ext"))
		File.write(File.join(root, "release.cert"), "certificate")
		File.write(File.join(root, ".rspec"), "--format documentation\n")
		
		File.write(gemspec_path, <<~RUBY)
			# frozen_string_literal: true
			
			Gem::Specification.new do |spec|
				spec.name = "example"
				spec.version = "1.0.0"
				spec.summary = "An example gem."
				spec.authors = ["Samuel Williams"]
				spec.license = "MIT"
				spec.homepage = "https://github.com/socketry/example/"
				spec.files = ["lib/example/version.rb", ".rspec"]
				spec.require_paths = ["lib", "ext"]
				spec.executables = ["example"]
				spec.extensions = ["ext/example/extconf.rb"]
				spec.add_dependency "console", "~> 1.0"
				spec.add_dependency "json"
				spec.add_development_dependency "sus", ">= 0"
			end
		RUBY
		
		result = update_gemspec
		
		expect(result).to be(:include?, "spec.cert_chain")
		expect(result).to be(:include?, %(spec.homepage = "https://github.com/socketry/example"))
		expect(result).to be(:include?, "File::FNM_DOTMATCH")
		expect(result).to be(:include?, %(spec.require_paths = ["lib"]))
		expect(result).to be(:include?, %(spec.executables = ["example"]))
		expect(result).to be(:include?, %(spec.extensions = ["ext/example/extconf.rb"]))
		expect(result).to be(:include?, %(spec.add_dependency "console", "~> 1.0"))
		expect(result).to be(:include?, %(spec.add_dependency "json"))
		expect(result).to be(:include?, %(spec.add_development_dependency "sus"))
	end
	
	it "moves development dependencies to gems.rb" do
		Dir.mktmpdir do |directory|
			File.write(File.join(directory, "gems.rb"), "source \"https://rubygems.org\"\n")
			dependencies = [
				Gem::Dependency.new("bundler", ">= 0"),
				Gem::Dependency.new("sus", "~> 0.37"),
			]
			
			expect(recipe.send(:move_development_dependencies, dependencies, directory)).to be == true
			
			result = File.read(File.join(directory, "gems.rb"))
			expect(result).to be(:include?, "# Moved Development Dependencies")
			expect(result).to be(:include?, %(gem "sus", "~> 0.37"))
			expect(result).not.to be(:include?, "bundler")
		end
	end
	
	it "formats bundler dependencies without requirements" do
		dependency = Gem::Dependency.new("bundler", "~> 2.0")
		
		expect(recipe.send(:format_dependency, dependency)).to be == %("bundler")
	end
	
	it "finds the default gemspec" do
		expect(recipe.send(:default_gemspec_path)).to be == "bake-modernize.gemspec"
	end
	
	it "selects the expected version path" do
		FileUtils.mkdir_p(File.join(root, "lib", "example"))
		FileUtils.mkdir_p(File.join(root, "lib", "other"))
		File.write(File.join(root, "lib", "example", "version.rb"), "")
		File.write(File.join(root, "lib", "other", "version.rb"), "")
		
		expect(recipe.send(:version_path, root, "example")).to be == "lib/example/version.rb"
	end
	
	it "falls back to the shortest version path" do
		FileUtils.mkdir_p(File.join(root, "lib", "a"))
		FileUtils.mkdir_p(File.join(root, "lib", "much", "longer"))
		File.write(File.join(root, "lib", "a", "version.rb"), "")
		File.write(File.join(root, "lib", "much", "longer", "version.rb"), "")
		
		expect(recipe.send(:version_path, root, "missing")).to be == "lib/a/version.rb"
	end
	
	it "detects optional GitHub metadata when URIs are valid" do
		spec = build_spec
		
		mock(recipe) do |mock|
			mock.replace(:valid_uri?){true}
		end
		
		expect(recipe.send(:detect_funding_uri, spec)).to be == "https://github.com/sponsors/socketry/"
		expect(recipe.send(:detect_documentation_uri, spec)).to be == "https://socketry.github.io/example/"
	end
	
	it "ignores optional GitHub metadata when URIs are invalid" do
		spec = build_spec
		
		mock(recipe) do |mock|
			mock.replace(:valid_uri?){false}
		end
		
		expect(recipe.send(:detect_funding_uri, spec)).to be_nil
		expect(recipe.send(:detect_documentation_uri, spec)).to be_nil
	end
	
	it "ignores GitHub metadata without a homepage" do
		spec = build_spec(homepage: nil)
		
		expect(recipe.send(:github_project, spec)).to be_nil
		expect(recipe.send(:detect_bug_tracker_uri, spec)).to be_nil
		expect(recipe.send(:detect_source_code_uri, spec)).to be_nil
		expect(recipe.send(:detect_changelog_uri, spec)).to be_nil
		expect(recipe.send(:detect_funding_uri, spec)).to be_nil
		expect(recipe.send(:detect_documentation_uri, spec)).to be_nil
	end
	
	it "validates URIs with HTTP HEAD" do
		requested_uri = nil
		response = Object.new
		response.define_singleton_method(:close){}
		response.define_singleton_method(:success?){true}
		
		internet = Object.new
		internet.define_singleton_method(:head) do |uri|
			requested_uri = uri
			response
		end
		
		mock(Async::HTTP::Internet) do |mock|
			mock.replace(:new){internet}
		end
		
		expect(recipe.send(:valid_uri?, "https://example.com/")).to be == true
		expect(requested_uri).to be == "https://example.com/"
	end
end
