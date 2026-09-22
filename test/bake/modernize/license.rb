# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023-2026, by Samuel Williams.

require "bake/modernize/license"
require "sus/fixtures/temporary_directory_context"

describe Bake::Modernize::License::SkipList do
	include Sus::Fixtures::TemporaryDirectoryContext
	
	let(:path) {File.join(root, Bake::Modernize::License::GIT_BLAME_IGNORE_REVS)}
	
	it "loads revisions from a directory" do
		File.write(path, "# Comment\n\nabc123\n")
		
		skip_list = subject.for(root)
		commit = Struct.new(:oid).new("abc123")
		
		expect(skip_list.ignore?(commit)).to be == true
	end
	
	it "returns nil when no skip list exists" do
		expect(subject.for(root)).to be_nil
	end
end

describe Bake::Modernize::License::Mailmap do
	include Sus::Fixtures::TemporaryDirectoryContext
	
	let(:mailmap) {subject.new}
	let(:path) {File.join(root, ".mailmap")}
	
	it "loads mailmap entries from a directory" do
		File.write(path, "# Comment\n\nSamuel Williams <samuel@example.org> <ioquatix@example.org>\n")
		
		mailmap = subject.for(root)
		
		expect(mailmap.names["ioquatix@example.org"]).to be == "Samuel Williams"
	end
	
	it "returns nil when no mailmap exists" do
		expect(subject.for(root)).to be_nil
	end
	
	it "can parse a proper name and commit email" do
		user = mailmap.extract_from_line("Samuel Williams <samuel@example.org>")
		
		expect(user[:proper_name]).to be == "Samuel Williams"
		expect(user[:commit_email]).to be == "samuel@example.org"
	end
	
	it "can parse a proper name, commit name and commit email" do
		user = mailmap.extract_from_line("Samuel Williams <samuel@example.org> <ioquatix@example.org>")
		
		expect(user[:proper_name]).to be == "Samuel Williams"
		expect(user[:proper_email]).to be == "samuel@example.org"
		expect(user[:commit_email]).to be == "ioquatix@example.org"
	end
	
	it "can parse a proper name, proper email, commit name and commit email" do
		user = mailmap.extract_from_line("Samuel Williams <samuel@example.org> ioquatix <ioquatix@example.org>")
		
		expect(user[:proper_name]).to be == "Samuel Williams"
		expect(user[:proper_email]).to be == "samuel@example.org"
		expect(user[:commit_name]).to be == "ioquatix"
		expect(user[:commit_email]).to be == "ioquatix@example.org"
	end
end

describe Bake::Modernize::License::Contributors do
	include Sus::Fixtures::TemporaryDirectoryContext
	
	let(:mailmap) {Bake::Modernize::License::Mailmap.new}
	let(:contributors) {subject.new(mailmap: mailmap)}
	let(:path) {File.join(root, ".contributors.yaml")}
	
	it "loads contributors from a directory" do
		File.write(path, <<~YAML)
			---
			- author:
			    name: Jane Doe
			    email: jane@example.com
			  time: 2026-01-01 00:00:00 UTC
		YAML
		
		contributors = subject.for(root, mailmap: mailmap)
		paths = contributors.paths_for(contributors.contributions.first).to_a
		
		expect(paths).to be == ["."]
	end
	
	it "returns nil when no contributors file exists" do
		expect(subject.for(root, mailmap: mailmap)).to be_nil
	end
	
	it "can iterate over contributions without mailmap" do
		contributors_without_mailmap = subject.new
		
		contribution = {
			author: {name: "John Doe", email: "john@example.com"},
			time: Time.new(2023, 1, 1),
			path: "test.rb"
		}
		
		contributors_without_mailmap.contributions << contribution
		
		results = []
		contributors_without_mailmap.each do |path, author, time|
			results << {path: path, author: author, time: time}
		end
		
		expect(results.length).to be == 1
		expect(results[0][:path]).to be == "test.rb"
		expect(results[0][:author][:name]).to be == "John Doe"
		expect(results[0][:author][:email]).to be == "john@example.com"
	end
	
	it "applies mailmap transformations when available" do
		mailmap.names["john@old-email.com"] = "John Smith"
		
		contribution = {
			author: {name: "John Doe", email: "john@old-email.com"},
			time: Time.new(2023, 1, 1),
			path: "test.rb"
		}
		
		contributors.contributions << contribution
		
		results = []
		contributors.each do |path, author, time|
			results << {path: path, author: author, time: time}
		end
		
		expect(results.length).to be == 1
		expect(results[0][:author][:name]).to be == "John Smith"
		expect(results[0][:author][:email]).to be == "john@old-email.com"
	end
	
	it "preserves original author data when no mailmap mapping exists" do
		mailmap.names["other@email.com"] = "Other Person"
		
		contribution = {
			author: {name: "John Doe", email: "john@example.com"},
			time: Time.new(2023, 1, 1),
			path: "test.rb"
		}
		
		contributors.contributions << contribution
		
		results = []
		contributors.each do |path, author, time|
			results << {path: path, author: author, time: time}
		end
		
		expect(results.length).to be == 1
		expect(results[0][:author][:name]).to be == "John Doe"
		expect(results[0][:author][:email]).to be == "john@example.com"
	end
	
	it "handles contributions without email address" do
		mailmap.names["john@example.com"] = "John Smith"
		
		contribution = {
			author: {name: "John Doe"},
			time: Time.new(2023, 1, 1),
			path: "test.rb"
		}
		
		contributors.contributions << contribution
		
		results = []
		contributors.each do |path, author, time|
			results << {path: path, author: author, time: time}
		end
		
		expect(results.length).to be == 1
		expect(results[0][:author][:name]).to be == "John Doe"
		expect(results[0][:author][:email]).to be == nil
	end
end

describe Bake::Modernize::License::Authorship::Modification do
	let(:author) {{name: "Samuel Williams", email: "samuel@example.com"}}
	let(:time) {Time.new(2026, 1, 1, 0, 0, 0, "+00:00")}
	
	it "provides author and serialization helpers" do
		modification = subject.new(author, time, "lib/example.rb", nil)
		
		expect(modification.full_name).to be == "Samuel Williams"
		expect(modification.key).to be == "samuel@example.com:2026-01-01T00:00:00+00:00"
		expect(modification.to_h).to be == {
			id: nil,
			time: time,
			path: "lib/example.rb",
			author: author,
		}
	end
	
	it "uses an explicit id as the key" do
		modification = subject.new(author, time, "lib/example.rb", "commit-id")
		
		expect(modification.key).to be == "commit-id"
	end
end

describe Bake::Modernize::License::Authorship::Copyright do
	it "adds period when author doesn't end with one" do
		copyright = subject.new([Time.new(2023), Time.new(2024)], "Samuel Williams")
		
		expect(copyright.statement).to be == "Copyright, 2023-2024, by Samuel Williams."
	end
	
	it "doesn't add extra period when author already ends with one" do
		copyright = subject.new([Time.new(2023), Time.new(2024)], "Widgets Inc.")
		
		expect(copyright.statement).to be == "Copyright, 2023-2024, by Widgets Inc."
	end
	
	it "sorts by date and author" do
		first = subject.new([Time.new(2023)], "A Person")
		second = subject.new([Time.new(2024)], "B Person")
		
		expect(first <=> second).to be == -1
	end
end

describe Bake::Modernize::License::Authorship do
	include Sus::Fixtures::TemporaryDirectoryContext
	
	let(:authorship) {subject.new}
	let(:time) {Time.new(2026, 1, 1, 0, 0, 0, "+00:00")}
	let(:author) {{name: "Samuel Williams", email: "samuel@example.com"}}
	
	def write_commit(repository, path, content, author:, message: "Commit.")
		full_path = File.join(repository.workdir, path)
		FileUtils.mkdir_p(File.dirname(full_path))
		File.write(full_path, content)
		
		repository.index.add_all
		repository.index.write
		
		parents = repository.empty? ? [] : [repository.head.target]
		tree = repository.index.write_tree(repository)
		
		Rugged::Commit.create(
			repository,
			message: message,
			author: author,
			committer: author,
			parents: parents,
			tree: tree,
			update_ref: "HEAD",
		)
	end
	
	it "adds modifications and summarizes authors" do
		authorship.add("lib/example.rb", author, time)
		
		expect(authorship.sorted_authors).to be == ["Samuel Williams"]
		expect(authorship.copyrights.map(&:statement)).to be == ["Copyright, 2026, by Samuel Williams."]
		expect(authorship.copyrights_for_path("lib/example.rb").map(&:statement)).to be == ["Copyright, 2026, by Samuel Williams."]
	end
	
	it "ignores bot modifications in copyrights and gem authors" do
		authorship.add("lib/example.rb", author, time)
		authorship.add("lib/example.rb", {name: "github-actions[bot]"}, time)
		authorship.add("lib/example.rb", {name: "dependabot[bot]"}, time)
		
		expect(authorship.sorted_authors).to be == ["Samuel Williams"]
		expect(authorship.copyrights.map(&:author)).to be == ["Samuel Williams"]
		expect(authorship.copyrights_for_path("lib/example.rb").map(&:author)).to be == ["Samuel Williams"]
	end
	
	it "ignores bots from imported contributors and preserves attribution through bot renames" do
		File.write(File.join(root, ".contributors.yaml"), [{
			author: {name: "dependabot[bot]", email: "bot@example.com"},
			time: time,
			path: "lib/example.rb",
		}].to_yaml)
		
		repository = Rugged::Repository.init_at(root)
		write_commit(repository, "lib/example.rb", "example\n", author: author.merge(time: time))
		FileUtils.mv(File.join(root, "lib/example.rb"), File.join(root, "lib/renamed.rb"))
		write_commit(repository, "lib/renamed.rb", "example\n", author: {name: "github-actions[bot]", email: "bot@example.com", time: time})
		
		authorship.extract(root)
		
		expect(authorship.sorted_authors).to be == ["Samuel Williams"]
		expect(authorship.copyrights_for_path("lib/renamed.rb").map(&:author)).to be == ["Samuel Williams"]
	end
	
	it "extracts authorship from contributors and git history" do
		File.write(File.join(root, ".contributors.yaml"), [{
			author: {name: "Contributor Name", email: "contributor@example.com"},
			time: Time.new(2025, 1, 1, 0, 0, 0, "+00:00"),
			path: "README.md",
		}].to_yaml)
		File.write(File.join(root, ".mailmap"), "Samuel Williams <samuel@example.com> <old@example.com>\n")
		
		repository = Rugged::Repository.init_at(root)
		commit_author = {name: "Old Name", email: "old@example.com", time: time}
		write_commit(repository, "lib/example.rb", "example\n", author: commit_author)
		FileUtils.rm(File.join(root, "lib", "example.rb"))
		write_commit(repository, "lib/renamed.rb", "example\n", author: commit_author)
		
		result = authorship.extract(root)
		
		expect(result).to be == authorship
		expect(authorship.sorted_authors).to be(:include?, "Samuel Williams")
		expect(authorship.sorted_authors).to be(:include?, "Contributor Name")
		expect(authorship.paths).to be(:include?, "lib/renamed.rb")
	end
end
