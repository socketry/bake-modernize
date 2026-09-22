# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022-2026, by Samuel Williams.

require "rugged"
require "yaml"

module Bake
	module Modernize
		# Support the analysis of authorship and license details.
		module License
			GIT_BLAME_IGNORE_REVS = ".git-blame-ignore-revs"
			
			# Represents revisions to skip when analyzing authorship.
			class SkipList
				# Load the skip list from a directory.
				def self.for(root)
					full_path = File.join(root, GIT_BLAME_IGNORE_REVS)
					
					if File.exist?(full_path)
						skip_list = self.new
						skip_list.extract(full_path)
						return skip_list
					end
				end
				
				# Create a new skip list with the given revisions.
				#
				# @parameter revisions [Array(String)] The revisions to skip.
				def initialize(revisions = [])
					@revisions = Set.new(revisions)
				end
				
				# Extract the revisions from the given path.
				def extract(path)
					File.open(path, "r") do |file|
						file.each_line do |line|
							# Skip empty lines and comments
							next if line =~ /^\s*(#|$)/
							# Parse line
							@revisions << line.strip
						end
					end
				end
				
				# Check if the given commit should be ignored.
				def ignore?(commit)
					@revisions.include?(commit.oid)
				end
			end
			
			# Represents a mailmap file which maps commit emails to proper names.
			class Mailmap
				# Load the mailmap from a directory.
				def self.for(root)
					full_path = File.join(root, ".mailmap")
					
					if File.exist?(full_path)
						mailmap = self.new
						mailmap.extract(full_path)
						return mailmap
					end
				end
				
				# Create a new, empty, mailmap.
				def initialize
					@names = {}
				end
				
				# @attribute [Hash(String, String)] The mapping of commit emails to proper names.
				attr :names
				
				# Extract the mailmap from the given path.
				def extract(path)
					File.open(path, "r") do |file|
						file.each_line do |line|
							# Skip comments
							next if line =~ /^#/
							# Skip empty lines
							next if line =~ /^\s*$/
							# Parse line
							
							
							user = extract_from_line(line)
							if commit_email = user[:commit_email] and proper_name = user[:proper_name]
								@names[commit_email] = proper_name
							end
						end
					end
				end
				
				# Format: Proper Name <proper@email.xx> Commit Name <commit@email.xx>
				PATTERN = /
					(?<proper_name>[^<]+)?
					(\s+<(?<proper_email>[^>]+)>)?
					(\s+(?<commit_name>[^<]+)?)?
					\s+<(?<commit_email>[^>]+)>
				/x
				
				# Extract the mailmap format from a line of input.
				def extract_from_line(line)
					line.match(PATTERN)
				end
			end
			
			# Extract contributors from a YAML file which can be generated from another repository.
			class Contributors
				# The default path is the root of the repository and for authors who have contributed to the entire repository or unspecified paths in the past.
				DEFAULT_PATH = "."
				
				# Load contributors from a directory.
				def self.for(root, mailmap: nil)
					full_path = File.join(root, ".contributors.yaml")
					
					if File.exist?(full_path)
						contributors = self.new(mailmap: mailmap)
						contributors.extract(full_path)
						return contributors
					end
				end
				
				# Create a new, empty, contributors list.
				def initialize(mailmap: nil)
					@contributions = []
					@mailmap = mailmap
				end
				
				# @attribute [Array(Hash)] The list of contributions.
				attr :contributions
				
				# Iterate over each contribution.
				def each(&block)
					@contributions.each do |contribution|
						author = contribution[:author].dup
						time = contribution[:time]
						
						# Apply mailmap transformation if available
						if @mailmap && author[:email] && mapped_name = @mailmap.names[author[:email]]
							author[:name] = mapped_name
						end
						
						paths_for(contribution) do |path|
							yield path, author, time
						end
					end
				end
				
				# Extract the contributors from the given path.
				def extract(path)
					@contributions.concat(
						YAML.load_file(path, aliases: true, symbolize_names: true, permitted_classes: [Symbol, Date, Time])
					)
				end
				
				# @attribute [Array(Hash)] The list of paths from a given contribution.
				def paths_for(contribution)
					return to_enum(:paths_for, contribution) unless block_given?
					
					if path = contribution[:path]
						yield path
					# elsif paths = contribution[:paths]
					# 	paths.each do |path|
					# 		yield path
					# 	end
					else
						yield DEFAULT_PATH
					end
				end
			end
			
			# Represents the authorship of a repository.
			class Authorship
				# Represents a modification to a file.
				Modification = Struct.new(:author, :time, :path, :id) do
					# The full name of the author who made the modification.
					# @returns [String] The author's display name.
					def full_name
						author[:name]
					end
					
					# The stable key used to group modifications by commit or contribution.
					# @returns [String] The modification key.
					def key
						self.id || "#{self.author[:email]}:#{self.time.iso8601}"
					end
					
					# Convert the modification to a serializable hash.
					# @returns [Hash] The modification data.
					def to_h
						{
							id: id,
							time: time,
							path: path,
							author: author,
						}
					end
				end
				
				# Represents the copyright for an author.
				Copyright = Struct.new(:dates, :author) do
					# Compare copyrights by their dates and author.
					# @parameter other [Copyright] The other copyright to compare.
					# @returns [Integer] The comparison result.
					def <=> other
						self.to_a <=> other.to_a
					end
					
					# Generate the copyright statement for the author.
					# @returns [String] The formatted copyright statement.
					def statement
						years = self.dates.map(&:year).uniq
						period = author.end_with?(".") ? "" : "."
						return "Copyright, #{years.join('-')}, by #{author}#{period}"
					end
				end
				
				# Create a new, empty, authorship.
				def initialize
					@paths = Hash.new{|h,k| h[k] = []}
					@commits = Hash.new{|h,k| h[k] = []}
				end
				
				# @attribute [Hash(String, Array(Modification))] The mapping of paths to modifications.
				attr :paths
				
				# @attribute [Hash(String, Array(Modification))] The mapping of commits to modifications.
				attr :commits
				
				# Add a modification to the authorship.
				def add(path, author, time, id = nil)
					return if author[:name].end_with?("[bot]")
					
					modification = Modification.new(author, time, path, id)
					
					@commits[modification.key] << modification
					@paths[path] << modification
				end
				
				# Extract the authorship from the given root directory.
				def extract(root = Dir.pwd)
					mailmap = Mailmap.for(root)
					skip_list = SkipList.for(root)
					
					if contributors = Contributors.for(root, mailmap: mailmap)
						contributors.each do |path, author, time|
							add(path, author, time)
						end
					end
					
					walk(Rugged::Repository.discover(root), mailmap: mailmap, skip_list: skip_list)
					
					return self
				end
				
				# Authors, sorted by contribution date.
				def sorted_authors
					authors = Hash.new{|h,k| h[k] = 0}
					
					@commits.each do |key, modifications|
						modifications.map(&:full_name).uniq.each do |full_name|
							authors[full_name] += 1
						end
					end
					
					return authors.sort_by{|k,v| [-v, k]}.map(&:first)
				end
				
				# All copyrights.
				def copyrights
					copyrights_for_modifications(@paths.values.flatten)
				end
				
				# All copyrights for a given path.
				def copyrights_for_path(path)
					copyrights_for_modifications(@paths[path])
				end
				
				# All copyrights for a given modification.
				def copyrights_for_modifications(modifications)
					authors = modifications.group_by{|modification| modification.full_name}
					
					authors.map do |name, modifications|
						Copyright.new(modifications.map(&:time).minmax, name)
					end.sort
				end
				
				private
				
				DEFAULT_SORT = Rugged::SORT_DATE | Rugged::SORT_TOPO | Rugged::SORT_REVERSE
				
				def walk(repository, mailmap: nil, skip_list: nil, show: "HEAD")
					Rugged::Walker.walk(repository, show: show, sort: DEFAULT_SORT) do |commit|
						next if skip_list&.ignore?(commit)
						
						diff = commit.diff
						
						# We relax the threshold for copy and rename detection because we want to detect files that have been moved and modified more generously.
						diff.find_similar!(
							rename_threshold: 25,
							copy_threshold: 25,
							ignore_whitespace: true,
						)
						
						diff.each_delta do |delta|
							old_path = delta.old_file[:path]
							new_path = delta.new_file[:path]
							
							@paths[new_path] ||= []
							
							if old_path != new_path
								# The file was moved, move copyright information too:
								Console.logger.debug(self, "Moving #{old_path} to #{new_path}", similarity: delta.similarity)
								@paths[new_path].concat(@paths[old_path])
							end
							
							author = commit.author
							
							if mailmap
								if name = mailmap.names[author[:email]]
									author[:name] = name
								end
							end
							
							add(new_path, author, commit.time, commit.oid)
						end
					end
				end
			end
		end
	end
end
