# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "async/ollama"
require "bake/modernize/gems"
require "sus/fixtures/temporary_directory_context"

describe Bake::Modernize::Gems do
	include Sus::Fixtures::TemporaryDirectoryContext
	
	let(:gems_path) {File.join(root, "gems.rb")}
	
	it "detects gem declarations" do
		content = <<~RUBY
			group :test do
				gem "bake-test", "~> 1.0"
				gem 'bake-test-external'
			end
		RUBY
		
		expect(subject.present?(content, "bake-test")).to be_truthy
		expect(subject.present?(content, "bake-test-external")).to be_truthy
		expect(subject.present?(content, "decode")).to be_falsey
	end
	
	it "removes gem declarations deterministically" do
		File.write(gems_path, <<~RUBY)
			source "https://rubygems.org"
			
			group :test do
				gem "bake-test"
				gem "bake-test-external", require: false
			end
		RUBY
		
		expect(subject.remove(gems_path, "bake-test-external")).to be_truthy
		
		content = File.read(gems_path)
		expect(content).to be(:include?, %{gem "bake-test"})
		expect(content).not.to be(:include?, "bake-test-external")
	end
	
	it "does nothing when removing a missing gem" do
		content = %{source "https://rubygems.org"\n}
		File.write(gems_path, content)
		
		expect(subject.remove(gems_path, "bake-test-external")).to be_falsey
		expect(File.read(gems_path)).to be == content
	end
	
	it "ensures dependencies using a validated transform" do
		content = <<~RUBY
			source "https://rubygems.org"
			
			group :test do
				gem "bake-test"
			end
		RUBY
		updated = content.sub(%{	gem "bake-test"\n}, %{	gem "bake-test"\n\tgem "bake-test-external"\n})
		File.write(gems_path, content)
		
		mock(Async::Ollama::Transform) do |mock|
			mock.replace(:call) do |input, model:, instruction:, template:|
				expect(input).to be == content
				expect(model).to be == Bake::Modernize::DEFAULT_TRANSFORM_MODEL
				expect(instruction).to be(:include?, "Ensure the `bake-test-external` gem")
				expect(template).to be(:include?, %{gem "bake-test-external"})
				updated
			end
		end
		
		expect(subject.ensure_dependency(gems_path, "bake-test-external", group: :test, template: updated)).to be_truthy
		expect(File.read(gems_path)).to be == updated
	end
	
	it "rejects invalid transform output" do
		File.write(gems_path, %{source "https://rubygems.org"\n})
		
		mock(Async::Ollama::Transform) do |mock|
			mock.replace(:call) do
				%{source "https://rubygems.org"\n}
			end
		end
		
		expect do
			subject.ensure_dependency(gems_path, "bake-test-external", group: :test, template: %{gem "bake-test-external"\n})
		end.to raise_exception(ArgumentError)
	end
end
