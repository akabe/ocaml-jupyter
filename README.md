# OCaml Jupyter

[![Jupyter protocol][protocol-img]][protocol] [![License][license-img]][license] [![CI](https://github.com/akabe/ocaml-jupyter/actions/workflows/ci.yaml/badge.svg)](https://github.com/akabe/ocaml-jupyter/actions/workflows/ci.yaml) [![Sponsor](https://img.shields.io/static/v1?label=Sponsor&message=%E2%9D%A4&logo=GitHub&color=ff69b4&link=https://github.com/sponsors/srz-zumix
)](https://github.com/sponsors/akabe)

[license]:      https://github.com/akabe/ocaml-jupyter/blob/master/LICENSE
[license-img]:  https://img.shields.io/badge/license-MIT-blue.svg
[protocol]:     https://jupyter-client.readthedocs.io/en/stable/messaging.html
[protocol-img]: https://img.shields.io/badge/Jupyter%20protocol-5.2-blue.svg
[travis]:       https://travis-ci.org/akabe/ocaml-jupyter
[travis-img]:   https://img.shields.io/travis/akabe/ocaml-jupyter/master.svg?label=travis
[jupyter]:      https://jupyter.org/
[opam]:         https://opam.ocaml.org/

An OCaml kernel for [Jupyter notebook][jupyter].

This provides an OCaml REPL with a great user interface such as markdown/HTML documentation, LaTeX formula by MathJax, and image embedding.

![Screenshot](https://akabe.github.io/ocaml-jupyter/images/screenshot.png)

## Getting started

OCaml Jupyter requires the libraries zlib, libffi, libgmp, libzmq 5+. Type one of the following commands suitable for your environment.

```shell
# For Debian or Ubuntu:
sudo apt-get install -y zlib1g-dev libffi-dev libgmp-dev libzmq5-dev
# For REHL or CentOS:
sudo yum install -y epel-release
sudo yum install -y zlib-devel libffi-dev gmp-devel zeromq-devel
# For Mac OS X:
brew install zlib libffi gmp zeromq
```

OCaml Jupyter can be installed by [OPAM][opam] as follows:

``` shell
pip install jupyter
opam install jupyter
opam install jupyter-archimedes  # Jupyter-friendly 2D plotting library
grep topfind ~/.ocamlinit || echo '#use "topfind";;' >> ~/.ocamlinit  # For using '#require' directive
ocaml-jupyter-opam-genspec
jupyter kernelspec install [ --user ] --name "ocaml-jupyter-$(opam var switch)" "$(opam var share)/jupyter"
```

If the last command fails due to permission, `--user` option or `sudo` is required. You can use `ocaml-jupyter` kernel by launching Jupyter notebook server:

```shell
jupyter notebook
```

If you get an error related to `archimedes.cairo` during installation of `jupyter-archimedes`,
manually install `cairo2` before `archimedes`:

```shell
opam install "cairo2<0.6"
opam reinstall archimedes
opam install jupyter-archimedes
```

### Development version

```shell
opam pin add jupyter https://github.com/akabe/ocaml-jupyter.git
```

## Usage

### Examples

- [Introduction](https://github.com/akabe/ocaml-jupyter/blob/master/notebooks/introduction.ipynb):
  a very simple example for use of OCaml Jupyter and sub-packages.
- [Get a description of a word from DuckDuckGo API](https://github.com/akabe/ocaml-jupyter/blob/master/notebooks/word_description_from_DuckDuckGoAPI.ipynb):
  request to DuckDuckGo API server by `cohttp.lwt`, and parse a response JSON by `yojson` and `ppx_deriving_yojson`.

In addition, many examples (e.g, image processing, voice analysis, etc.) are available at
[docker-ocaml-jupyter-datascience/notebooks](https://github.com/akabe/docker-ocaml-jupyter-datascience/tree/master/notebooks).

These examples are placed in the **public domain**, e.g., you can edit, copy, and re-distribute with no copyright messages.

### Code completion

OCaml Jupyter kernel supports [merlin](https://ocaml.github.io/merlin/)-based code completion. Candidates are shown by Tab key like

![Code completion](https://akabe.github.io/ocaml-jupyter/images/completion.png)

The kernel uses [.merlin](https://github.com/ocaml/merlin/wiki/project-configuration) file at a notebook directory for completion.

### Inspection

_Inspection_ in Jupyter is also achieved by merlin. You can see documentation and type of an identifier by Shift+Tab key like

![Inspection](https://akabe.github.io/ocaml-jupyter/images/inspect.png)

### API documentation

OCaml Jupyter includes some sub-packages:

- [jupyter][jupyter-core] is a core library of OCaml Jupyter. This package is internally used. You don't need it directly.
- [jupyter.notebook][jupyter-notebook] is a library to control Jupyter from OCaml REPL in notebooks. This provides dynamic generation of HTML/markdown, and image embedding.
- [jupyter.comm][jupyter-comm] is a library for communication between OCaml notebooks and Jupyter/Web frontend.
- [jupyter-archimedes][jupyter-archimedes] is a Jupyter backend for [Archimedes][archimedes], an easy-to-use 2D plotting library. This package only registers the `jupyter` backend to Archimedes, and provides an empty interface.

[jupyter-core]:       https://akabe.github.io/ocaml-jupyter/api/jupyter/
[jupyter-notebook]:   https://akabe.github.io/ocaml-jupyter/api/jupyter/Jupyter_notebook/
[jupyter-comm]:       https://akabe.github.io/ocaml-jupyter/api/jupyter/Jupyter_comm/
[jupyter-archimedes]: https://akabe.github.io/ocaml-jupyter/api/jupyter-archimedes/
[archimedes]:         http://archimedes.forge.ocamlcore.org/

### NBConvert

OCaml notebooks can be converted to HTML, Markdown, LaTeX, `.ml` files, etc. using the `jupyter nbconvert` command.
For example, a `.ipynb` file is converted into a `.html` file as follows:

```console
$ jupyter nbconvert --to html notebooks/introduction.ipynb
[NbConvertApp] Converting notebook notebooks/introduction.ipynb to html
[NbConvertApp] Writing 463004 bytes to notebooks/introduction.html
```

For exporting `.ml` files, we recommend [Jupyter-NBConvert-OCaml][Jupyter-NBConvert-OCaml]. It outputs `.ml` files with Markdown cells as comments. After installation of Jupyter-NBConvert-OCaml, you can use `--to ocaml` option to export a `.ml` file:

```console
$ jupyter nbconvert --to ocaml notebooks/introduction.ipynb
[NbConvertApp] Converting notebook notebooks/introduction.ipynb to ocaml
[NbConvertApp] Writing 2271 bytes to notebooks/introduction.ml
```

[Jupyter-NBConvert-OCaml]: https://github.com/Naereen/Jupyter-NBConvert-OCaml

### Customize kernel parameters

`ocaml-jupyter-opam-genspec` generates a configuration file like:

```console
$ cat "$(opam var share)/jupyter/kernel.json"
{
  "display_name": "OCaml 4.08.1",
  "language": "OCaml",
  "argv": [
    "/bin/sh",
    "-c",
    "eval $(opam env --switch=4.08.1) && /home/xxxx/.opam/4.08.1/bin/ocaml-jupyter-kernel \"$@\"",
    "-init", "/home/xxxx/.ocamlinit",
    "--merlin", "/home/xxxx/.opam/4.08.1/bin/ocamlmerlin",
    "--verbosity", "app",
    "--connection-file", "{connection_file}"
  ]
}
```

See `ocaml-jupyter-kernel --help` for details of command-line parameters in `argv`. After you edit the file, re-register the kernel:

```shell
jupyter kernelspec install --name ocaml-jupyter "$(opam var share)/jupyter"
```

### Installation without OPAM

`ocaml-jupyter-opam-genspec` depends on OPAM. If you use an other package manager, you need to write `kernel.json` by hand or use provided suitable way for registering a new kernel (e.g., [jupyter module](https://nixos.org/nixos/options.html#jupyter.kernels) on  [Nix](https://nixos.org/nix/)).

## Running OCaml Jupyter on other environments

### Binder

OCaml Jupyter can be run on [Binder](https://www.mybinder.org).  Click
the button to get started:
[![Binder](https://mybinder.org/badge_logo.svg)](https://mybinder.org/v2/gh/edmcman/ocaml-jupyter-binder-environment/master?urlpath=git-pull%3Frepo%3Dhttps%253A%252F%252Fgithub.com%252Fakabe%252Fdocker-ocaml-jupyter-datascience%26urlpath%3Dtree%252Fdocker-ocaml-jupyter-datascience%252Fnotebooks%252Fintroduction.ipynb%26branch%3Dmaster)

For more information, see this [repository](https://github.com/edmcman/ocaml-jupyter-binder-environment).

### Google Colab

OCaml Jupyter can be run on Google Colab. In order to do this you first have to run
[this Python notebook](http://colab.research.google.com/github/akabe/ocaml-jupyter/blob/master/notebooks/install_ocaml_colab.ipynb)
in your Colab instance. This will install the kernel and after that OCaml notebooks can be used on the same instance.

## Sponsors

If you like this project, please support by becoming a sponsor via [GitHub Sponsors](https://github.com/sponsors/akabe).

[<img width=200 src="https://raw.githubusercontent.com/akabe/ocaml-jupyter/gh-pages/images/sponsors/ahrefs.svg"/>](https://ahrefs.com/)

## Related work

Many Jupyter kernels for functional programming languages are available such as [IHaskell][ihaskell], [Jupyter Scala][jupyter-scala], and [Jupyter Rust][jupyter-rs]. [IOCaml][iocaml] is another practical OCaml kernel that inspires us, but it seems no longer maintained. OCaml Jupyter kernel differs from IOCaml in

|                        | OCaml Jupyter | IOCaml v0.4.8 |
| ---------------------- | ------------- | ------------- |
| Jupyter protocol       | v5.2          | v3.2          |
| OCaml PPX support      | Yes           | No            |
| Session key support    | Yes           | No            |
| Code completion        | Yes           | Yes           |
| Introspection          | Yes           | Yes           |
| User-defined messages  | Yes           | No            |
| Stdin                  | Yes           | No            |

Another OCaml kernel [simple_jucaml][simple_jucaml] seems too simple to use in practice.
[jupyter-kernel][jupyter-kernel] is a library to write OCaml kernels (*not a kernel*), but OCaml Jupyter kernel does not use this library.

[ihaskell]:      https://github.com/gibiansky/IHaskell
[jupyter-scala]: https://github.com/alexarchambault/jupyter-scala
[jupyter-rs]:    https://github.com/pwoolcoc/jupyter-rs
[iocaml]:        https://github.com/andrewray/iocaml
[simple_jucaml]: https://github.com/KKostya/simple_jucaml
[jupyter-kernel]:https://github.com/ocaml-jupyter/jupyter-kernel
