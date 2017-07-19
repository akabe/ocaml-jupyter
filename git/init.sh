#!/bin/bash -eu

git_topdir=$(git rev-parse --show-toplevel 2>/dev/null)
git_gitdir=$(pwd)/$(git rev-parse --git-dir 2>/dev/null)

if [[ "${git_topdir}" != '' ]]; then
	ln -f "${git_topdir}/git/pre-commit" "${git_gitdir}/hooks/pre-commit"
fi
