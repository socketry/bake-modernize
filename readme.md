# Bake Modernize

A gem for modernizing files in your Ruby project.

[![Development Status](https://github.com/ioquatix/bake-modernize/workflows/Test/badge.svg)](https://github.com/ioquatix/bake-modernize/actions?workflow=Test)

## Usage

Please see the [project documentation](https://ioquatix.github.io/bake-modernize/) for more details.

## Releases

Please see the [project releases](https://ioquatix.github.io/bake-modernize/releases/index) for all releases.

### v0.54.1

  - Better `version.rb` detection in `modernize:gemspec`.

### v0.53.0

  - Make `modernize:releases` part of the default `modernize` task.

### v0.52.0

  - Add support for automatic GitHub release generation.

### v0.43.0

  - Improved copilot instructions for using agent context.

### v0.33.0

  - Add `modernize:releases` to add release notes.

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
