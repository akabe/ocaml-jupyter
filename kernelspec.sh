#!/bin/bash -eu

function check_user_mode() {
    local jupyter=$(type -p jupyter 2>/dev/null)

    if [[ "$jupyter" == '' ]]; then
        return 1
    elif [[ "$jupyter" =~ ^$HOME ]]; then
        return 0
    else
        return 1
    fi
}

function get_ocaml_version() {
    if type -p opam >/dev/null 2>/dev/null; then
        opam switch show
    else
        ocaml -vnum
    fi
}

function create() {
    local bindir=$1

    cat <<EOF
{
  "display_name": "OCaml ${OCAML_VERSION}",
  "language": "OCaml",
  "argv": [
    "${bindir}/ocaml-jupyter",
    "--init",
    "${HOME}/.ocamlinit",
    "--verbosity",
    "info",
    "--connection-file",
    "{connection_file}"
  ]
}
EOF
}

function install() {
    local install_kernel=$1
    local datadir=$2
    local install_flags="--name $KERNEL_NAME"

    if check_user_mode; then
        install_flags+=" --user"
    fi

    local cmd="jupyter kernelspec install ${install_flags} $datadir"

	if [[ "$install_kernel" == 'true' ]] && type -p jupyter >/dev/null 2>/dev/null; then
		echo "$cmd"
		eval $cmd
	else
		cat <<EOF
=*=*=*=*=*=*=*=*=*=*= Add ocaml-jupyter kernel =*=*=*=*=*=*=*=*=*=*=

  You can add ocaml-jupyter kernel to Jupyter by the following command:

  \$ $cmd
EOF
	fi
}

OCAML_VERSION=$(get_ocaml_version | sed 's@[^0-9A-Za-z_\.+-]@_@g')
KERNEL_NAME="ocaml-jupyter-${OCAML_VERSION}"

case $1 in
    create )
		create $2
    ;;
    install )
        install $2 $3
	;;
	uninstall )
		jupyter kernelspec remove "$KERNEL_NAME" -f || :
	;;
esac
