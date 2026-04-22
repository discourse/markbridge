# Vendored mutant skill

This directory vendors [mutant's SKILL.md](https://github.com/mbj/mutant/blob/main/SKILL.md)
so Claude Code auto-loads the author's mutation-testing playbook when
mutant is in use.

**Pinned to mutant commit [`efadfe18`](https://github.com/mbj/mutant/commit/efadfe18d6044f05de8600a243a12f300727d42f)**
(2026-03-17). Refresh manually when we want newer skill guidance; don't
auto-update on CI.

Not shipped in the `mutant` gem yet (as of 0.16.0), so we vendor rather
than load from the gem path. If a future release ships it, switch to
the gem copy and delete this vendor.

## Refresh

```sh
curl -s https://raw.githubusercontent.com/mbj/mutant/<new-sha>/SKILL.md \
  -o .claude/skills/mutant/SKILL.md
```

Then update the pinned SHA in this README.
