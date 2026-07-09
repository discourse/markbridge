# Release

## When to Activate

- The user asks to release a new version of the gem.

## Prerequisites

- Everything meant for the release is already merged to main — merging
  PRs is NOT part of releasing and needs its own explicit approval.
- CI is green on the latest main push (the publish job is gated on
  lint, the test matrix, and the mutation job).

## Steps

1. On an up-to-date main: set the new version in
   `lib/markbridge/version.rb`.
2. Run `bundle install` — this updates the `markbridge` entry in
   `Gemfile.lock`.
3. Commit exactly those two files as `DEV: Bump version to X.Y.Z`
   (see 8731ca4 for the shape).
4. Preview the release notes before pushing:
   `bin/generate-release-notes` — this is exactly what CI will publish.
   Entries come from FEATURE:/FIX:/PERF: commit subjects (rebase
   merges) or squash-body bullets; DEV:/DEPS: are dropped.
5. Push the commit to main — with approval; do not push on your own.

CI does the rest on that push: the publish job releases the gem to
RubyGems (discourse/publish-rubygems-action creates the vX.Y.Z tag)
and creates the GitHub release with the generated notes.

## Verification

- `gh run watch` (or `gh run list --branch main`) until the publish
  job succeeds.
- `gh release view vX.Y.Z` shows the notes; the gem appears on
  rubygems.org shortly after.

## Troubleshooting

- Publish skipped, "Release vX.Y.Z already exists": the tag/release
  was created earlier; bump again or delete the release deliberately.
- Empty or missing notes: check the commit subjects in the release
  range — only FEATURE:/FIX:/PERF: prefixes appear. Squash merges rely
  on the repo's squash message setting (COMMIT_MESSAGES) putting
  "* <subject>" bullets in the body.
- Publish job did not run: one of lint/test/mutation failed on the
  main push; fix that first — the gate is intentional.
