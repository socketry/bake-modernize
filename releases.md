# Releases

## v0.61.0

  - Provide agent context for updating gems and configuring GitHub releases.
  - Ignore `[bot]` authors in copyright attributions and gem authors.
  - Add opt-in `modernize:releases:github` migration and omit redundant publishing hooks for gems using `bake-gem-github`.

## v0.60.0

  - Ignore `/vendor/bundle` by default for dependencies installed by GitHub Actions' Bundler cache.

## v0.54.1

  - Better `version.rb` detection in `modernize:gemspec`.

## v0.53.0

  - Make `modernize:releases` part of the default `modernize` task.

## v0.52.0

  - Add support for automatic GitHub release generation.

## v0.43.0

  - Improved copilot instructions for using agent context.

## v0.33.0

  - Add `modernize:releases` to add release notes.
