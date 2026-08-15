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
	
	it "removes travis configuration" do
		File.write(File.join(root, ".travis.yml"), "language: ruby\n")
		
		mock(recipe) do |mock|
			mock.replace(:system){}
		end
		
		task.call(root: root)
		
		expect(File.exist?(File.join(root, ".travis.yml"))).to be_falsey
	end
	
	it "updates readme badges" do
		repository = Rugged::Repository.init_at(root)
		repository.remotes.create("origin", "git@github.com:ioquatix/bake-modernize.git")
		
		readme_path = File.join(root, "README.md")
		File.write(readme_path, <<~MARKDOWN)
			# Bake Modernize
			
			[![Old](https://example.com/badge.svg)](https://example.com)
			
			## Usage
		MARKDOWN
		
		updates = []
		mock(recipe) do |mock|
			mock.replace(:update_badges) do |path, url|
				updates << [path, url]
			end
			mock.replace(:system){}
		end
		
		task.call(root: root)
		
		expect(updates).to be == [["README.md", "https://github.com/ioquatix/bake-modernize"]]
	end
	
	it "updates legacy workflow filenames" do
		workflows_path = File.join(root, ".github", "workflows")
		FileUtils.mkdir_p(workflows_path)
		File.write(File.join(workflows_path, "build.yml"), "name: Build\n")
		File.write(File.join(workflows_path, "development.yaml"), "name: Development\n")
		File.write(File.join(workflows_path, "coverage.yaml"), "name: Coverage\n")
		
		recipe.send(:update_filenames, root)
		
		expect(File.exist?(File.join(workflows_path, "build.yaml"))).to be_truthy
		expect(File.exist?(File.join(workflows_path, "test.yaml"))).to be_truthy
		expect(File.exist?(File.join(workflows_path, "test-coverage.yaml"))).to be_truthy
	end
	
	it "creates a standard test workflow without optional ruby implementations" do
		recipe.send(:update_workflows, root)
		
		content = File.read(File.join(root, ".github", "workflows", "test.yaml"))
		expect(content).to be(:include?, "ruby: head")
		expect(content).not.to be(:include?, "ruby: jruby")
		expect(content).not.to be(:include?, "ruby: truffleruby")
	end
	
	it "merges existing test workflow configuration without re-adding removed optional rubies" do
		workflows_path = File.join(root, ".github", "workflows")
		FileUtils.mkdir_p(workflows_path)
		
		existing = <<~YAML
			name: Test
			on: [push, pull_request]
			jobs:
			  test:
			    services:
			      redis:
			        image: redis
			    strategy:
			      matrix:
			        include:
			          - os: ubuntu
			            ruby: jruby
			            experimental: true
			          - os: ubuntu
			            ruby: head
			            experimental: true
		YAML
		File.write(File.join(workflows_path, "test.yaml"), existing)
		
		mock(Async::Ollama::Transform) do |mock|
			mock.replace(:call) do |content, model:, instruction:, template:|
				expect(content).to be == existing
				expect(model).to be == "qwen3-coder:latest"
				expect(instruction).to be(:include?, "Preserve existing services")
				expect(instruction).to be(:include?, "jruby")
				expect(instruction).to be(:include?, "truffleruby")
				expect(template).to be(:include?, "ruby: jruby")
				expect(template).not.to be(:include?, "ruby: truffleruby")
				
				<<~YAML
					name: Test
					on: [push, pull_request]
					permissions:
					  contents: read
					jobs:
					  test:
					    name: ${{matrix.ruby}} on ${{matrix.os}}
					    runs-on: ${{matrix.os}}-latest
					    continue-on-error: ${{matrix.experimental}}
					    services:
					      redis:
					        image: redis
					    strategy:
					      matrix:
					        os:
					          - ubuntu
					          - macos
					        ruby:
					          - "3.3"
					          - "3.4"
					          - "4.0"
					        experimental: [false]
					        include:
					          - os: ubuntu
					            ruby: jruby
					            experimental: true
					          - os: ubuntu
					            ruby: head
					            experimental: true
					    steps:
					    - uses: actions/checkout@v7
					    - uses: ruby/setup-ruby@v1
					      with:
					        ruby-version: ${{matrix.ruby}}
					        bundler-cache: true
					    - name: Run tests
					      timeout-minutes: 10
					      run: bundle exec bake test
				YAML
			end
		end
		
		recipe.send(:update_workflows, root)
		
		content = File.read(File.join(workflows_path, "test.yaml"))
		expect(content).to be(:include?, "services:")
		expect(content).to be(:include?, "image: redis")
		expect(content).to be(:include?, "ruby: jruby")
		expect(content).not.to be(:include?, "ruby: truffleruby")
	end
	
	it "rejects invalid test workflow transform output" do
		workflows_path = File.join(root, ".github", "workflows")
		FileUtils.mkdir_p(workflows_path)
		
		File.write(File.join(workflows_path, "test.yaml"), <<~YAML)
			name: Test
			jobs:
			  test:
			    strategy:
			      matrix:
			        include:
			          - os: ubuntu
			            ruby: jruby
		YAML
		
		mock(Async::Ollama::Transform) do |mock|
			mock.replace(:call){"name: Test\n"}
		end
		
		expect do
			recipe.send(:update_test_workflow, File.join(workflows_path, "test.yaml"))
		end.to raise_exception(ArgumentError)
	end
	
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
			mock.replace(:system){}
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
			mock.replace(:system){}
		end
		
		task.call(root: root)
		
		external_workflow_path = File.join(root, ".github", "workflows", "test-external.yaml")
		expect(File.exist?(external_workflow_path)).to be_falsey
		
		expect(File.read(File.join(root, "gems.rb"))).not.to be(:include?, %{gem "bake-test-external"})
	end
	
	it "detects SSH repository URLs" do
		repository = Rugged::Repository.init_at(root)
		repository.remotes.create("origin", "git@github.com:ioquatix/bake-modernize.git")
		
		expect(recipe.send(:repository_url, root)).to be == "https://github.com/ioquatix/bake-modernize"
	end
	
	it "replaces existing readme badges" do
		readme_path = File.join(root, "readme.md")
		File.write(readme_path, <<~MARKDOWN)
			# Bake Modernize
			
			[![Old](https://example.com/badge.svg)](https://example.com)
			
			## Usage
		MARKDOWN
		
		recipe.send(:update_badges, readme_path, "https://github.com/ioquatix/bake-modernize")
		
		content = File.read(readme_path)
		expect(content).to be(:include?, "Development Status")
		expect(content).not.to be(:include?, "https://example.com")
	end
	
	it "inserts readme badges before the next heading" do
		readme_path = File.join(root, "readme.md")
		File.write(readme_path, <<~MARKDOWN)
			# Bake Modernize
			
			Introductory text.
			
			## Usage
		MARKDOWN
		
		recipe.send(:update_badges, readme_path, "https://github.com/ioquatix/bake-modernize")
		
		content = File.read(readme_path)
		expect(content).to be(:include?, "Development Status")
		expect(content.index("Development Status")).to be < content.index("## Usage")
	end
end
