FROM akabe/ocaml:__OCAML_VERSION__

RUN sudo apk update && \
    sudo apk add --upgrade --no-cache tzdata m4 bash perl git libressl-dev libffi-dev gmp-dev zeromq-dev

RUN opam update && \
    opam upgrade && \
    opam install -y \
      cppo lwt yojson 'ZMQ>=4.0-8' lwt-zmq nocrypto uuidm ppx_deriving_yojson \
      ocp-indent ppx_sexp_conv camlp4 'ounit>=2.0.0'
