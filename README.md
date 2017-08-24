# OCaml Jupyter

[![Kernel version][version-img]][version] [![Jupyter protocol][protocol-img]][protocol] [![License][license-img]][license] [![Travis Build Status][travis-img]][travis]

[version]:      https://github.com/akabe/ocaml-jupyter/releases
[version-img]:  https://img.shields.io/badge/version-1.0.1-blue.svg
[license]:      https://github.com/akabe/ocaml-jupyter/blob/master/LICENSE
[license-img]:  https://img.shields.io/badge/license-MIT-blue.svg
[protocol]:     http://jupyter-client.readthedocs.io/en/stable/messaging.html
[protocol-img]: https://img.shields.io/badge/Jupyter%20protocol-5.2-blue.svg
[travis]:       https://travis-ci.org/akabe/ocaml-jupyter
[travis-img]:   https://img.shields.io/travis/akabe/ocaml-jupyter/master.svg?label=travis
[jupyter]:      http://jupyter.org/
[opam]:         https://opam.ocaml.org/

An OCaml kernel for [Jupyter notebook][jupyter].

This provides an OCaml REPL with a great user interface such as markdown/HTML documentation, LaTeX formula by MathJax, and image embedding.

![Screenshot](https://akabe.github.io/ocaml-jupyter/images/screenshot.png)

A [Docker image][ocaml-jupyter-datascience] are distributed on DockerHub. It contains OCaml Jupyter and many packages for data science.

[ocaml-jupyter-datascience]: https://github.com/akabe/docker-ocaml-jupyter-datascience

## Getting started

OCaml Jupyter can be installed by [OPAM][opam] as follows:

``` console
$ pip install jupyter
$ opam install jupyter
```

which will automatically register the kernel to Jupyter.
After installation, you can use `ocaml-jupyter` kernel by launching Jupyter notebook server:

```console
$ jupyter notebook
```

### Development version

```console
$ opam pin add jupyter https://github.com/akabe/ocaml-jupyter.git
```

## Usage

### Examples

- [Introduction](https://github.com/akabe/ocaml-jupyter/blob/master/notebooks/introduction.ipynb):
  a very simple example for use of OCaml Jupyter and sub-packages.
- [Get a description of a word from DuckDuckGo API](https://github.com/akabe/ocaml-jupyter/blob/master/notebooks/word_description_from_DuckDuckGoAPI.ipynb):
  request to DuckDuckGo API server by `cohttp.lwt`, and parse a response JSON by `yojson` and `ppx_deriving_yojson`.

In addition, many examples (e.g, image processing, voice analysis, etc.) are available at
[docker-ocaml-jupyter-datascience/notebooks](https://github.com/akabe/docker-ocaml-jupyter-datascience/tree/master/notebooks).

These examples are publish in **public domain**, e.g., you can edit, copy, and re-distribute with no copyright messages.

### Code completion

OCaml Jupyter kernel supports [merlin][merlin]-based code completion. TAB key shows candidates as follows.

![Code completion][completion-img]

The kernel uses [.merlin][dot-merlin] file at a notebook directory for completion. We strongly recommend to install [jupyter-completion-hint][jupyter-completion-hint] nbextension to display types of identifiers:

![Code compltion with hints][completion-with-hint-img]

[merlin]:                   https://ocaml.github.io/merlin/
[dot-merlin]:               https://github.com/ocaml/merlin/wiki/project-configuration
[jupyter-completion-hint]:  https://github.com/akabe/jupyter-completion-hint
[completion-img]:           https://raw.githubusercontent.com/akabe/ocaml-jupyter/gh-pages/images/completion.png
[completion-with-hint-img]: https://raw.githubusercontent.com/akabe/ocaml-jupyter/gh-pages/images/completion-with-hint.png

### API documentation

OCaml Jupyter includes some sub-packages:

- [jupyter][jupyter-core]: definitions of Jupyter protocol. This package is internally used. You don't need it directly.
- [jupyter.notebook][jupyter-notebook]: a library to control Jupyter from OCaml REPL in notebooks. This provides dynamic generation of HTML/markdown, and image embedding.
- `jupyter.archimedes`: Jupyter backend of [Archimedes][archimedes], an easy-to-use 2D plotting library. This package only registers the `jupyter` backend to Archimedes, and provides no interface (`opam install cairo2 archimedes` is required.)

[jupyter-core]:     https://akabe.github.io/ocaml-jupyter/core/index.html
[jupyter-notebook]: https://akabe.github.io/ocaml-jupyter/notebook/index.html
[archimedes]:       http://archimedes.forge.ocamlcore.org/

### Customize kernel parameters

A kernelspec JSON is saved at the following path:

```console
$ cat "$(opam config var share)/ocaml-jupyter/kernel.json"
{
  "display_name": "OCaml 4.04.2",
  "language": "OCaml",
  "argv": [
    "/home/USERNAME/.opam/4.04.2/bin/ocaml-jupyter-kernel",
    "--init",
    "/home/USERNAME/.ocamlinit",
    "--verbosity",
    "info",
    "--connection-file",
    "{connection_file}"
  ]
}
```

See `ocaml-jupyter-kernel --help` for details of command-line parameters in `argv`. After you edit the file, re-register the kernel:

```console
$ jupyter kernelspec install --name ocaml-jupyter "$(opam config var share)/ocaml-jupyter"
[InstallKernelSpec] Removing existing kernelspec in /home/USERNAME/.local/share/jupyter/kernels/ocaml-jupyter-4.04.2
[InstallKernelSpec] Installed kernelspec ocaml-jupyter-4.04.2 in /home/USERNAME/.local/share/jupyter/kernels/ocaml-jupyter-4.04.2
```

## Related work

Many Jupyter kernels for functional programming languages are available such as [IHaskell][ihaskell], [Jupyter Scala][jupyter-scala], and [Jupyter Rust][jupyter-rs]. [IOCaml][iocaml] is another OCaml kernel that inspires us, but it seems no longer maintained. OCaml Jupyter kernel differs from IOCaml in

|                        | OCaml Jupyter | IOCaml v0.4.8 |
| ---------------------- | ------------- | ------------- |
| Jupyter protocol       | v5.2          | v3.2          |
| OCaml PPX support      | Yes           | No            |
| Session key support    | Yes           | No            |
| Code completion        | Yes           | Yes           |
| Introspection          | No            | Yes           |
| User-defined messages  | Yes           | No            |
| Stdin                  | Yes           | No            |

In addition, the installer of OCaml Jupyter automatically adds the kernel to Jupyter.

[ihaskell]:      https://github.com/gibiansky/IHaskell
[jupyter-scala]: https://github.com/alexarchambault/jupyter-scala
[jupyter-rs]:    https://github.com/pwoolcoc/jupyter-rs
[iocaml]:        https://github.com/andrewray/iocaml

## Contact

Open [Issue](https://github.com/akabe/ocaml-jupyter/issues) for any questions, bug reports, requests of new features. Your comments may help other users. Issues are a better way than direct contact (e.g., E-mails) to maintainers.

## Contribution

We welcome your patch!

1. Fork this repository and clone your repository.
2. `ln -sf $PWD/git/pre-commit $PWD/.git/hooks/pre-commit`
3. Create a new branch and commit your changes.
4. `git push` the commits into your (forked) repository.
5. Pull request to `master` of this repository from the branch you pushed.
