---
name: mutant
description: Run mutant, read mutation reports, fix alive mutations, and verify coverage. Use when running mutation testing or responding to alive mutations.
metadata:
  origin: markbridge project (original work; see README.md)
---

# Mutation testing with mutant

Use this skill when running mutation tests, working through alive
mutations, or checking mutation coverage for changed code.

## How this project runs mutant

- Always through the wrapper: `bin/mutant run`, never
  `bundle exec mutant`.
- Scope runs to what changed — a subject expression
  (`bin/mutant run 'Markbridge::Parsers::BBCode::Scanner*'`) or
  `--since origin/main`. Full runs are for CI.
- Configuration lives in `mutant.yml`. Two lists matter:
  `matcher.ignore` (whole subjects) and `mutation.ignore_patterns`
  (AST node patterns). Every entry needs an inline comment naming the
  surviving mutation and why it cannot be killed — no bare entries.

## Reading a run

A surviving mutation is reported as an `evil:` line
(`evil:SUBJECT:FILE:LINE:ID`) followed by a diff of original vs
mutated code. The console shows only the first mutation per subject;
the full per-mutation data lands in `.mutant/results/*.json`. To list
every alive diff from the latest run:

```sh
ruby -rjson -e '
  j = JSON.parse(File.read(Dir[".mutant/results/*.json"].max_by { File.mtime(_1) }))
  j["subject_results"].each do |sr|
    sr["coverage_results"].each do |cr|
      next if cr["criteria_result"].values.any? { |v| v == true }
      puts sr["identification"], cr["mutation_result"]["mutation_diff"]
    end
  end'
```

Timeouts are not failures by default here: mutations that drop a
`while` body loop forever and die on the clock. That is the accepted
kill for non-terminating mutants (a Ruby PRISM bug makes the
`while A && B` guard workaround worse than the timeouts — see the
project memory if this ever needs revisiting).

## Working an alive mutation

Ask, in this order:

1. **Is the mutated code wrong for some input?** Then the tests have a
   gap — add an example that passes on the original and fails on the
   mutant. Gaps we hit repeatedly in this codebase:
   - Byte/range comparisons need probes at *both endpoints and the
     adjacent bytes* of every range (`[a]`, `[z]`, `` [`] ``, `[{]` for
     an a–z check). Regexes don't have these mutation axes; integer
     comparisons do.
   - Walks and loops need inputs deep enough that "fails to advance
     past the second element" cannot masquerade as correct — two
     levels is often not enough, use three.
   - Allocation-avoidance code (copy-on-write, buffer reuse) is often
     only observable through **object identity** — `expect(x).to be(y)`
     kills mutants that `eq` cannot.
   - Booleans and flags need both values exercised; collections need
     more than one element; defaulted parameters need a call that
     omits them.
2. **Is the mutated code right for every input?** Then mutant found
   dead weight or an over-powered construct — apply the mutation to
   the source instead of fighting it. This has caught real leftovers
   here (a `@pos` reset that a rewrite made redundant, `= nil`
   assignments that unset ivars already provide). Verify against every
   call site before accepting, and watch for traps: an accepted
   `to_i → Integer()` "simplification" once introduced an
   octal-parsing crash on leading zeros — the fix was
   `Integer(value, 10, ...)`, not reverting.
3. **Is it equivalent and unkillable through the public API?** Then it
   goes on the ignore list *with a comment*. The recurring family is
   the fast-path guard: a branch that only skips allocations produces
   byte-identical output when mutated away, so nothing observable can
   kill it. Keep the guard, extract it into its own small method when
   that narrows the ignored surface, and never ignore a subject whose
   other mutations still need pressure.

## Project-specific traps

- **Test selection is by example-group name.** Mutant picks the specs
  whose describe-strings match the subject (`#initialize` examples for
  `Foo#initialize`). A killing example in the wrong describe block is
  invisible to the run — it passes rspec and the mutation stays alive.
  Put behavior-pinning examples under the describe of the method they
  kill mutations in.
- **Public API only.** No `send`/`__send__` to reach private methods
  and no test-only subclasses that publicize them. If a mutation is
  only observable by calling a private directly, that is what the
  ignore list is for.
- **No stubbing or mocking the class under mutation.**
- **`ignore_patterns` quirks:** the AST pattern language has no `?`/`!`
  in identifiers and is whitespace-insensitive; scope patterns by
  giving locals unique names (`span_end`) so a pattern cannot hit
  unrelated code.
- **MarkdownEscaper is special:** benchmark before and after any
  change there (`bundle exec ruby --yjit bench/bench.rb --single
  escape_plain` / `escape_mixed`); prefer adding tests over
  restructuring when behavior is equivalent.
- **Line coverage must not regress**: compare `COVERAGE=1 bin/rspec`
  before and after.

## Commits

Test additions and code changes go in separate commits — the killing
test first (it must pass against the unmutated code), the
simplification second. Tests-only work can be a single commit. Run the
full suite before every commit; subject-scoped runs miss cross-cutting
consumers.

## Reporting

Lead with the verdict per mutation — killed how, simplified why, or
unkillable with the reasoning — so the decision can be reviewed
without rereading the diffs. When something is unkillable, say what
was tried; that is the evidence the ignore-list comment needs anyway.

## Reference

Upstream's own playbook (not vendored here for licensing reasons —
mutant is EULA-licensed):
https://github.com/mbj/mutant/blob/main/SKILL.md
