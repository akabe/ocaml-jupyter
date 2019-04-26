# OCaml Jupyter

[![Jupyter protocol][protocol-img]][protocol] [![License][license-img]][license] [![Travis Build Status][travis-img]][travis]

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

OCaml Jupyter can be installed by [OPAM][opam] as follows:

``` console
$ pip install jupyter
$ opam install jupyter
$ opam install jupyter-archimedes  # Jupyter-friendly 2D plotting library
$ jupyter kernelspec install --name ocaml-jupyter "$(opam config var share)/jupyter"
```

which will add the kernel to Jupyter. You can use `ocaml-jupyter` kernel by launching Jupyter notebook server:

```console
$ jupyter notebook
```

If you get an error related to `archimedes.cairo` during installation of `jupyter-archimedes`,
manually install `cairo2` before `archimedes`:

```console
$ opam install "cairo2<0.6"
$ opam reinstall archimedes
$ opam install jupyter-archimedes
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

These examples are placed in the **public domain**, e.g., you can edit, copy, and re-distribute with no copyright messages.

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

### Registration of multiple kernels

You can add kernels of different versions of OCaml as different names like:

```console
$ opam switch create 4.06.0
$ jupyter kernelspec install --name ocaml-jupyter-4.06.0 "$(opam config var share)/jupyter"
$ opam switch create 4.07.1
$ jupyter kernelspec install --name ocaml-jupyter-4.07.1 "$(opam config var share)/jupyter"
```

`OCaml 4.06.0` and `OCaml 4.07.1` are displayed on Jupyter.
If you want to prepare kernels for each `opam-switch` environment,
the following command is useful:

```console
$ jupyter kernelspec install --name ocaml-jupyter-$(opam config var switch) "$(opam config var share)/jupyter"
```

### Customize kernel parameters

A kernelspec JSON is saved at the following path:

```console
$ cat "$(opam config var share)/jupyter/kernel.json"
{
  "display_name": "OCaml 4.04.2",
  "language": "OCaml",
  "argv": [
    "/bin/sh",
    "/home/USERNAME/.opam/4.04.2/share/jupyter/kernel.sh",
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
$ jupyter kernelspec install --name ocaml-jupyter "$(opam config var share)/jupyter"
```

## Docker image

A ready-to-use Docker image [akabe/ocaml-jupyter-datascience][ocaml-jupyter-datascience] is available on DockerHub.
It contains OCaml Jupyter and many packages for data science.

```console
$ docker run -it -p 8888:8888 akabe/ocaml-jupyter-datascience
[I 15:38:04.170 NotebookApp] Writing notebook server cookie secret to /home/opam/.local/share/jupyter/runtime/notebook_cookie_secret
[W 15:38:04.190 NotebookApp] WARNING: The notebook server is listening on all IP addresses and not using encryption. This is not recommended.
[I 15:38:04.197 NotebookApp] Serving notebooks from local directory: /notebooks
[I 15:38:04.197 NotebookApp] 0 active kernels
[I 15:38:04.197 NotebookApp] The Jupyter Notebook is running at: http://[all ip addresses on your system]:8888/?token=4df0fee0719115f474c8dd9f9281abed28db140d25f933e9
[I 15:38:04.197 NotebookApp] Use Control-C to stop this server and shut down all kernels (twice to skip confirmation).
[W 15:38:04.198 NotebookApp] No web browser found: could not locate runnable browser.
[C 15:38:04.198 NotebookApp]

    Copy/paste this URL into your browser when you connect for the first time,
    to login with a token:
        http://localhost:8888/?token=4df0fee0719115f474c8dd9f9281abed28db140d25f933e9
```

[ocaml-jupyter-datascience]: https://github.com/akabe/docker-ocaml-jupyter-datascience


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

## Contact

Open an [issue](https://github.com/akabe/ocaml-jupyter/issues) for any question, bug report, feature request. Your comments may help other users. Discussion in issues is better than contacting maintainers directly (e.g. by email).

## Contribution

We welcome your patch!

1. Fork this repository and clone your repository.
1. `ln -sf $PWD/git/pre-commit $PWD/.git/hooks/pre-commit`
1. `opam install ocp-indent` for code format (in the git pre-commit hook)
1. Create a new branch and commit your changes.
1. `git push` the commits into your (forked) repository.
1. Pull request to `master` of this repository from the branch you pushed.

The environment variable `OCAML_JUPYTER_LOG` controls the log level of OCaml Jupyter kernel.
The following setting verbosely outputs log messages. They might help you debug.

```console
$ export OCAML_JUPYTER_LOG='debug'
$ jupyter notebook
```
