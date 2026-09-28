# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "bake/modernize"
require "sus/fixtures/temporary_directory_context"

describe Bake::Modernize::Signing do
	include Sus::Fixtures::TemporaryDirectoryContext
	
	it "loads signing configuration when the project has a gemspec" do
		gemspec_path = File.join(root, "example.gemspec")
		File.write(gemspec_path, <<~RUBY)
			Gem::Specification.new do |spec|
				spec.name = "example"
				spec.version = "1.0.0"
				spec.signing_key = "/tmp/example.pem"
			end
		RUBY
		
		signing = subject.load(root)
		
		expect(signing.private_key_path).to be == "/tmp/example.pem"
	end
	
	it "loads signing configuration without a gemspec" do
		signing = subject.load(root)
		
		release_key_path = File.join(Bake::Modernize::Signing::GEM_CREDENTIALS_PATH, "release.pem")
		expect(signing.private_key_path).to be == release_key_path
	end
	
	it "derives the private key path from the available certificate" do
		signing = subject.new(Gem::Specification.new do |spec|
			spec.metadata = {"signing_owner" => "socketry"}
		end)
		certificate_path = File.join(
			Bake::Modernize::Signing::GEM_CREDENTIALS_PATH,
			"socketry-release.cert",
		)
		
		mock(File) do |mock|
			mock.replace(:file?) do |path|
				path == certificate_path
			end
			
			expect(signing.private_key_path).to be == certificate_path.sub(/\.cert\z/, ".pem")
		end
	end
	
	it "formats a private key outside the gem credentials directory as a literal" do
		signing = subject.new(Gem::Specification.new do |spec|
			spec.signing_key = "/tmp/example.pem"
		end)
		
		expect(signing.private_key_expression).to be == "/tmp/example.pem".inspect
	end
end
