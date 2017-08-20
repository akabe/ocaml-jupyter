#!/bin/bash -eu

function check_command() {
    type $1 >/dev/null 2>&1
}

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
    if check_command opam; then
        opam config var switch
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
    "${bindir}/ocaml-jupyter-kernel",
    "--init",
    "${HOME}/.ocamlinit",
    "--merlin",
    "${bindir}/ocamlmerlin",
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

    if [[ "$install_kernel" == 'true' ]] && check_command jupyter; then
        if check_user_mode; then
            jupyter kernelspec install --user $install_flags "$datadir"
        else
            sudo jupyter kernelspec install $install_flags "$datadir"
        fi
    fi
}

function uninstall() {
    if check_command jupyter; then
        if check_user_mode; then
            jupyter kernelspec remove "$KERNEL_NAME" -f
        else
            sudo jupyter kernelspec remove "$KERNEL_NAME" -f
		fi
    fi
}

OCAML_VERSION=$(get_ocaml_version | sed 's@[^0-9A-Za-z_\.+-]@_@g')
KERNEL_NAME=ocaml-jupyter

case $1 in
    create )
        create $2
    ;;
    install )
        install $2 $3
    ;;
    uninstall )
    	uninstall
	;;
esac
