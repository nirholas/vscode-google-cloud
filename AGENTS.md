# AGENTS.md

Operating notes for AI coding agents (Claude Code, Codex, Cursor, Copilot and others) working in this repository. Everything here is derived from the files actually in the tree, so trust it over guesses, and update it when the facts change.

## What this repository is

Run unlimited VS Code instances in your browser using Google Cloud. One script, full dev environment, no Codespaces limits.

- Source: https://github.com/nirholas/vscode-google-cloud
- Primary language: Shell
- License: Other (see the LICENSE file)

## Repository layout

- `README.md`
- `LICENSE`

## Setup

No package manifest is checked in. Follow the installation steps in `README.md`.

## Commands

No build, test or lint scripts are declared in the tree. Verify changes by running the project as `README.md` describes.

## Conventions

- `.env` files are gitignored; never commit credentials, and read configuration from environment variables.
- Commit messages follow Conventional Commits (`type(scope): summary`), matching the existing history.
- Read the surrounding code before adding to it, and match its naming, file organisation and error-handling style.
- Keep `README.md` accurate: if a change alters behaviour, commands or configuration, update the docs in the same commit.
- Do not leave TODO comments, stub functions, placeholder data or commented-out code behind. Finish what you start or leave it out.
- Small, focused commits with a subject line that describes the change, not the act of committing.

## Where to raise things

- Bugs and feature requests: https://github.com/nirholas/vscode-google-cloud/issues
- Questions and ideas: https://github.com/nirholas/vscode-google-cloud/discussions
- Security issues: report privately at https://github.com/nirholas/vscode-google-cloud/security/advisories/new, never in a public issue.
