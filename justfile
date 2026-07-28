# Repository quality checks. `just ci` is the same read-only check developers
# and CI should run before publishing documentation.

markdownlint:
    bunx markdownlint-cli2@0.23.2

# Apply safe automatic Markdown formatting fixes locally. Review the diff
# before committing; CI always runs the read-only `markdownlint` recipe.
markdownlint-fix:
    bunx markdownlint-cli2@0.23.2 --fix

ci: markdownlint
