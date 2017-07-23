# ocaml-jupyter &nbsp;&nbsp; [![Kernel version][version-img]][version] ![Jupyter protocol][protocol-img] [![License][license-img]][license] [![Travis Build Status][travis-img]][travis]

[version]:      https://github.com/akabe/ocaml-jupyter/releases
[version-img]:  https://img.shields.io/badge/version-0.0.0-blue.svg
[license]:      https://github.com/akabe/ocaml-jupyter/blob/master/LICENSE
[license-img]:  https://img.shields.io/badge/license-MIT-blue.svg
[protocol-img]: https://img.shields.io/badge/Jupyter%20protocol-5.2-blue.svg
[travis]:       https://travis-ci.org/akabe/ocaml-jupyter
[travis-img]:   https://img.shields.io/travis/akabe/ocaml-jupyter/master.svg?label=travis
[jupyter]:      http://jupyter.org/
[opam]:         https://opam.ocaml.org/

An OCaml kernel for [Jupyter notebook][jupyter].

This provides an OCaml REPL with a great user interface such as markdown/HTML documentation, LaTeX formula by MathJax, and image embedding.

## Getting started

Installation requires [Jupyter][jupyter], [OPAM][opam] and OCaml >= 4.03.2.
The current development version can be installed by

```console
$ git clone https://github.com/akabe/ocaml-jupyter
$ cd ocaml-jupyter/
$ opam pin add jupyter .
```

which will automatically register the kernel to Jupyter.
After installation, you can use `ocaml-jupyter` kernel by launching Jupyter notebook server:

```console
$ jupyter notebook
```
