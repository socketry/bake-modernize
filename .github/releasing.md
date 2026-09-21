# Releases

Prepare releases with `bundle exec bake gem:github:release:patch` (or `minor` / `major`), or dispatch `release-prepare.yaml` on the default branch. Core `gem:release:branch:*` tasks only create a local branch and commit; they do not push or publish.

Review the entire release diff. Native GitHub rules require the configured reviews and CI, including an up-to-date branch and **Release validation**. Administrators can explicitly bypass the review/check rules. A rebase is sufficient only if regenerated content still matches. If notes are stale, prepare again from the current default branch and preserve any manual edits separately for review.

Merging a version increase publishes the actual merged commit through `release-publish.yaml`. There is no second release approval. The public `release.cert` stays in Git; the optional private key belongs in the Actions secret `GEM_SIGNING_KEY`, supplied by the `rubygems` environment or an organization secret. RubyGems authentication uses Trusted Publishing.

Before uploading to RubyGems, the publisher preserves the verified gem, receipt and both attestation bundles as assets of a draft GitHub release. The draft becomes public after registry verification and tag creation. Registry propagation is retried for up to one minute.

If a publishing job fails, use **Re-run all jobs** on that same workflow run, or `bundle exec bake gem:github:release:resume run=RUN_ID`. The original artifact is restored from the workflow artifact or GitHub release before another upload is attempted. Actions artifacts can disappear on rerun, so the draft release is the durable backup. Do not delete it, create a replacement version bump or rebuild an already-published version. Conflicting bytes or tags require investigation; never automatically yank a version or move a tag. An incomplete draft requires restoring the missing original files before retrying.

Verify both the downloaded gem and `release.json` with `gh attestation verify`, enforcing the publishing workflow's certificate identity and default branch ref. Then check the signed receipt's source commit and gem digest; follow the companion gem's setup guide for the complete commands. `--source-digest` checks the workflow revision, which can differ from the release commit. Release assets include the gem, RubyGems Sigstore bundle, GitHub provenance bundle, and signed source/digest receipt.

The initial implementation supports public repositories, a single gemspec, stable patch/minor/major versions, and merge/squash commits. Keep rebase merges and merge queues disabled. Generation hooks must be repeatable from the same source and version. Run setup and account recovery checks before enabling publishing; see the companion gem's setup guide.
