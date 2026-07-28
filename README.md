# theknow

Research and other info so I don't have to repeat myself

## Development

Run the full repository check before committing documentation:

```bash
just ci
```

This runs the pinned [markdownlint-cli2](https://github.com/DavidAnson/markdownlint-cli2)
check through `bunx` against every Markdown file. To apply the formatter-style
fixes supported by the linter locally, run `just markdownlint-fix` and review
the resulting diff.
