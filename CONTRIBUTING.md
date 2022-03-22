# Contribution Guide

## Issues

We accept [issues](https://github.com/akabe/ocaml-jupyter/issues) as follows:

- Bug reports
- Questions
- Feature requests
- Suggestion of improvement

You can post any other topic. If you have a question or found a bug, please explain what your problem is and how to reproduce it for maintainers, e.g., your environments, commands, and operations on Jupyter.

Your comments may help other users. Discussion in issues is better than contacting maintainers directly (e.g. by email).

## Pull Request

We always welcome your pull request.

1. Fork this repository and clone your repository.
1. `opam install . -y --deps-only --with-test && opam install 'merlin>=3.0.0'`
1. Create a new branch.
1. Run `make format` and commit your changes.
1. `git push` the commits into your (forked) repository.
1. Pull request to `master` of this repository from the branch you pushed.

## Tests

```shell
make format     # Lint and code formatting
make unit-test  # Unit tests
```

## Debugging Tips

### Logging

The environment variable `OCAML_JUPYTER_LOG` controls the log level of OCaml Jupyter kernel.
The following setting verbosely outputs log messages. They might help you debug.

```console
export OCAML_JUPYTER_LOG='debug'
jupyter notebook
```
