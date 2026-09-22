# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023-2026, by Samuel Williams.

require "bake/modernize"
require "markly"

def contributing
	if conduct_path = Dir["conduct.md"]
		FileUtils.rm_f(conduct_path)
	end
	
	update_contributing(File.join(Dir.pwd, "readme.md"))
end

private

DEFAULT_CONTRIBUTING = <<~EOF
## Contributing

We welcome contributions to this project.

1.  Fork the repository.
2.  Create your feature branch (`git checkout -b my-new-feature`).
3.  Commit your changes (`git commit -am 'Add some feature.'`).
4.  Push to the branch (`git push origin my-new-feature`).
5.  Create a new pull request.

### Running Tests

To run the test suite:

``` bash
$ bundle exec sus
```

### Making Releases

To make a new release:

``` bash
$ bundle exec bake gem:release:patch # or minor or major
```

### Developer Certificate of Origin

In order to protect users of this project, we require all contributors to comply with the [Developer Certificate of Origin](https://developercertificate.org/). This ensures that all contributions are properly licensed and attributed.

### Community Guidelines

This project is best served by a collaborative and respectful environment. Treat each other professionally, respect differing viewpoints, and engage constructively. Harassment, discrimination, or harmful behavior is not tolerated. Communicate clearly, listen actively, and support one another. If any issues arise, please inform the project maintainers.
EOF

def update_contributing(readme_path)
	root = Markly.parse(File.read(readme_path))
	
	contributing = DEFAULT_CONTRIBUTING
	if Bake::Modernize.gem_dependencies(File.dirname(readme_path)).include?("bake-gem-github")
		contributing = contributing.sub("gem:release:patch", "gem:github:release:patch")
		contributing = contributing.sub("### Developer Certificate of Origin", "See [bake-gem-github](https://github.com/socketry/bake-gem-github) for setup and release instructions.\n\n### Developer Certificate of Origin")
	end
	
	replacement = Markly.parse(contributing)
	
	return unless node = root.find_header("Contributing")
	
	node.replace_section(replacement)
	
	File.write(readme_path, root.to_markdown(width: 0))
end
