# Getting Started

This guide explains how to update a Ruby gem with `bake-modernize`, review the generated changes, and optionally migrate to releases through GitHub.

## Installation

Add the tools to the project's maintenance dependencies, preserving the existing groups and version requirements:

``` ruby
group :maintenance, optional: true do
	gem "agent-context"
	gem "bake-modernize"
end
```

Install the maintenance group and its agent guidance:

``` bash
bundle config set --local with maintenance
bundle install
bundle exec bake agent:context:install
```

If `bake-modernize` is already installed, use `bundle update bake-modernize --conservative` to update it, then reinstall the agent context. Read the project's instructions and relevant dependency guides before making changes. Generated `agents.md` and installed context are local working files; do not commit them.

## Update a gem

Start from an up-to-date checkout with a clean working tree and create a branch for the modernization. Check the gem's supported Ruby versions, CI jobs, release process, signing configuration, and custom Bake tasks before updating them.

List the available tasks, then run the default modernization from the gem's root directory:

``` bash
bundle exec bake list modernize
bundle exec bake modernize
git diff
```

The default task updates standard files including CI workflows, dependency manifests, the gemspec, copyright attributions, contributing instructions, and release hooks. It modifies the working tree directly. Review the diff and selectively keep appropriate changes; generated changes are suggestions, and repository customizations can be intentional. Some tasks install gems, inspect GitHub URLs, or use Ollama with `qwen3-coder:latest` to merge existing files. Those merges need a running Ollama service with that model available.

You can run individual tasks when only part of the project needs updating:

``` bash
bundle exec bake modernize:actions
bundle exec bake modernize:license
bundle exec bake modernize:releases
```

Check the resulting Ruby compatibility requirements, gem dependencies, workflow names and required status checks, gemspec file list, signing paths, and release hooks. Preserve custom tasks and project-specific CI. Copyright generation ignores author names ending in `[bot]`; `.mailmap`, `.contributors.yaml`, and human authorship through file renames remain supported.

Run the project's checks before opening a PR. For gems using the standard Sus, RuboCop, and Decode tasks:

``` bash
bundle exec bake test
bundle exec rubocop
bundle exec bake decode:index:coverage lib
```

Add user-visible changes under `## Unreleased` in `releases.md`. If guides or project documentation changed, run `bundle exec bake utopia:project:update` and review its output. Commit the selected changes and describe any remaining manual setup in the PR.

## Opt in to GitHub releases

The default `modernize` task does not migrate the publishing process. To adopt reviewed release PRs explicitly:

``` bash
bundle exec bake modernize:releases:github
```

This task adds `bake-gem-github` to maintenance dependencies, removes the direct `bake-gem` dependency when present, and updates release notes and Bake hooks. `bake-gem-github` supplies `bake-gem` and `bake-releases` as dependencies. Existing `bake-gem-github` version requirements are preserved.

Keep `after_gem_release_version_increment`, which updates release notes and project documentation. GitHub publishing replaces the `after_gem_release` call to `releases:github:release`. When merging an existing `bake.rb`, review the generated edit to ensure it removes that call while preserving unrelated custom behavior. Subsequent `modernize:releases` runs select the same template based on the target project's dependencies and do not add the publishing hook back. Contributing instructions also use `gem:github:release:patch` for projects that have adopted it.

Configure the release workflows separately using the installed gem's setup task. Pass the actual required CI job names; for example, a repository using the standard Ruby matrix and coverage workflows might use:

``` bash
bundle exec bake gem:github:setup checks="3.3 on ubuntu,3.3 on macos,3.4 on ubuntu,3.4 on macos,4.0 on ubuntu,4.0 on macos,check,ruby on ubuntu,ruby on macos,validate"
bundle exec bake gem:github:setup:plan
```

For an existing `config/release.yaml`, use `bundle exec bake gem:github:setup:update` to regenerate managed files instead. Review and commit the generated workflows, rulesets, configuration, and readme changes. Keep the readme's `Making Releases` section short: a release command and a link to [bake-gem-github](https://github.com/socketry/bake-gem-github).

Complete the setup described by [bake-gem-github](https://github.com/socketry/bake-gem-github): configure the RubyGems Trusted Publisher for `release-publish.yaml` and the `rubygems` environment, restrict that environment to the default branch, and install a matching signing key if signing is enabled. Select environment reviewers per repository when a separate publishing approval is wanted, for example `reviewers: [socketry/managers]`. Omitting reviewers leaves the environment's existing reviewer configuration unchanged.

After the setup PR is merged and the required CI jobs are available, an administrator reviews the plan and runs `bundle exec bake gem:github:setup:apply`. Generating files or upgrading gems does not apply remote settings. Workflow execution approvals, PR reviews, and publishing environment approvals are separate controls.

Once setup is complete, prepare a release with `bundle exec bake gem:github:release:patch` (or `minor` or `major`), or dispatch `release-prepare.yaml` remotely. Merge the reviewed release PR to start publishing.
