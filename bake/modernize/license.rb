# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022-2026, by Samuel Williams.

require "bake/modernize"
require "markly"

LICENSE = <<~LICENSE
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
LICENSE

# @parameter root [String] The root directory to scan for changes.
def license(root: Dir.pwd)
	update(root: root)
end

def update(root:)
	authorship = Bake::Modernize::License::Authorship.new
	authorship.extract(root)
	
	buffer = StringIO.new
	buffer.puts "# MIT License"
	buffer.puts
	
	authorship.copyrights.each do |copyright|
		buffer.puts "#{copyright.statement}  "
	end
	
	buffer.puts
	buffer.puts LICENSE
	
	File.open("license.md", "w") do |file|
		file.write(buffer.string)
	end
	
	remove_license(File.join(root, "readme.md"))
	
	authorship.paths.each do |path, modifications|
		next unless File.exist?(path)
		
		case path
		when /\.rb$/
			self.update_source_file_authors(authorship, path, modifications)
		end
	end
end

private

def update_source_file_authors(authorship, path, modifications)
	copyrights = authorship.copyrights_for_modifications(modifications)
	Bake::Modernize::License::SourceFile.update(path, copyrights: copyrights.map(&:statement))
end

def remove_license(readme_path)
	root = Markly.parse(File.read(readme_path))
	
	if node = root.find_header("License")
		node.replace_section(nil)
	end
	
	File.write(readme_path, root.to_markdown(width: 0))
end
