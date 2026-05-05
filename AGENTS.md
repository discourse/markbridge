# CLAUDE.md

Markbridge converts BBCode, HTML, MediaWiki wikitext, and s9e/TextFormatter XML to
Discourse-flavored Markdown via a Parse → AST → Render pipeline. Architecture, AST shape,
parser/renderer guides, extension points, and performance notes live in `docs/`. Read those
before proposing structural changes — this file only carries project-specific rules an
agent can't derive from the code or the docs site.

## Workflow

- Use `bundle exec` for gem commands (except `bin/*` scripts).
- Run `bin/lint` before opening a PR. Lefthook also runs on commit (RuboCop, Syntax Tree, RBS).
- Mutation testing wrapper is `bin/mutant`, not `bundle exec mutant`.
- Never commit while specs are red. Per-file runs miss cross-cutting consumers — run the full
  suite (`bundle exec rake` or `bin/rspec`) before committing.

## Style guardrails (not enforced by RuboCop)

- Every Ruby file starts with `# frozen_string_literal: true`.
- No monkey-patching of Ruby core classes.
- Use `private`, not `protected`.
- Use `attr_reader` over `attr_accessor` unless mutability is required.
- Keyword arguments for methods with multiple parameters.
- Prefer `instance_double` over `double` (RSpec/VerifiedDoubles is enabled).

## Mutation testing rules

- Test through the public API only. No `send` / `__send__` to private methods. No test-only
  subclasses that publicize private helpers (`Class.new(described_class) { public :helper }`).
- No stubbing or mocking of the SUT (the class currently being mutated).
- If a mutation is only observable by calling a private method directly, add it to the
  `mutant.yml` ignore list with an inline comment that names the surviving mutation and
  summarizes what was tried — don't reach behind the curtain.
- Capture baseline line coverage with `COVERAGE=1 bin/rspec` before changes; re-run after to
  verify no regression.
- Code changes and test changes go in separate commits — test first, code-simplification
  second. Tests-only changes can be a single commit.
- The full mutant playbook is vendored at `.claude/skills/mutant/SKILL.md` — read it first.

## Hot path

`Renderers::Discourse::MarkdownEscaper` is performance-critical. Benchmark before and after
any change to `lib/markbridge/renderers/discourse/markdown_escaper.rb` (a `--yjit` micro-bench
is fine). Prefer adding tests over refactoring when behavior is equivalent.

## Where to look

- `docs/` — architecture, AST, parsers, renderers, extending, performance.
- `examples/` — runnable end-to-end examples.
- `spec/` — executable documentation. Tiers: `spec/unit/` (class isolation),
  `spec/integration/` (component interactions), `spec/system/` (end-to-end
  format → Markdown), `spec/docs/` (cross-checks between code and the docs site,
  e.g. AST class coverage).
