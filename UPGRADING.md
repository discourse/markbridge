# Upgrading Markbridge

The upgrade guide now lives on the docs site:

**https://markbridge.dev/reference/upgrading/**

It covers the breaking changes between releases (the `Conversion`/`Parse`
result types, the single `renderer:` kwarg, signature changes) and the new
capabilities the redesign added (`allow:`, `escape: false`, editing the AST
between parse and render, pre-parsed Nokogiri input, AST traversal helpers,
and `AST::Details`).
