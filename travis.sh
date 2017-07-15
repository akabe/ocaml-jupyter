#!/bin/bash -xeu

sudo chown opam:opam -R $PWD

./git/pre-commit

./configure --enable-tests
make
make test
