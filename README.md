# OCaml Jupyter &nbsp;&nbsp; [![Kernel version][version-img]][version] [![Jupyter protocol][protocol-img]][protocol] [![License][license-img]][license] [![Travis Build Status][travis-img]][travis]

[version]:      https://github.com/akabe/ocaml-jupyter/releases
[version-img]:  https://img.shields.io/badge/version-0.0.0-blue.svg
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

## Usage

### API documentation

OCaml Jupyter includes some sub-packages:

- [jupyter][jupyter-core]: definitions of Jupyter protocol. This package is internally used. You don't need it directly.
- [jupyter.notebook][jupyter-notebook]: a library to control Jupyter from OCaml REPL in notebooks. This provides dynamic generation of HTML/markdown, and image embedding.
- `jupyter.archimedes`: Jupyter backend of [Archimedes][archimedes], an easy-to-use 2D plotting library. This package has no interface, but it registers the `jupyter` backend to Archimedes.

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
$ jupyter kernelspec install --name "ocaml-jupyter-$(opam config var switch)" "$(opam config var share)/ocaml-jupyter"
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
| Code completion        | Todo          | Yes           |
| Introspection          | Todo          | Yes           |
| User-defined messages  | Todo          | No            |
| Stdin                  | Todo          | No            |

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
