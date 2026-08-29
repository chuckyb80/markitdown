#!/bin/bash
# SessionStart hook for Claude Code on the web.
#
# Installs markitdown's dependencies so tests and the linter work inside a
# fresh remote session. Only runs remotely -- a local dev machine is
# expected to already have its own environment (see README.md "Running
# Tests and Checks", which uses `hatch`).
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

cd "$CLAUDE_PROJECT_DIR"

# Work around a broken base image: the apt-installed `cryptography` package
# links against a `_cffi_backend` built for python3.12, but `python3` here
# is 3.11, so anything importing cryptography (pdfminer.six, azure-identity,
# msal -- all pulled in by markitdown[all]) crashes with a PyO3 panic. Force
# a fresh wheel; it lands ahead of the apt package on sys.path and shadows
# it. --ignore-installed is required because the apt package has no pip
# RECORD file, so a normal upgrade refuses to touch it.
python3 -m pip install --quiet --ignore-installed cryptography

# This is a uv/hatch workspace of four packages under packages/. Install all
# of them in editable mode so `import markitdown` etc. picks up src/ edits
# without reinstalling, and pull in markitdown's [all] extra so every
# converter's dependencies (pandas, pdfminer.six, python-pptx, mammoth,
# azure-*, ...) are present -- CI (.github/workflows/tests.yml) exercises
# the full `hatch test` suite, not just the dependency-free core.
python3 -m pip install --quiet \
  -e 'packages/markitdown[all]' \
  -e packages/markitdown-ocr \
  -e packages/markitdown-mcp \
  -e packages/markitdown-sample-plugin

# Test/lint tooling. hatch-test's env (packages/markitdown/pyproject.toml)
# adds pytest + openai on top of [all]; pre-commit.yml's only hook is
# black. Install them straight into this same environment rather than via
# hatch, and prefer types-check tooling (mypy) too since tool.hatch.envs.types
# scripts reference it.
#
# NOTE: this container also ships pytest/black/mypy/ruff on PATH as
# isolated `uv tool` installs -- those venvs cannot see markitdown, so
# always invoke via `python3 -m pytest` / `python3 -m black`, not the bare
# command, or imports will fail.
python3 -m pip install --quiet pytest openai black mypy
