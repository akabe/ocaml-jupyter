NON_CPPO_SOURCES = $(shell find src tests \( -name '*.ml' -or -name '*.mli' \) -not -name '*.cppo.*')
KERNEL_NAME = ocaml-jupyter-$(shell opam var switch)
OCAML_JUPYTER_LOG = debug

.PHONY: format check-format test unit-test integration-test

format:
	opam exec -- ocp-indent -i $(NON_CPPO_SOURCES)

check-format:
	@res=0; for f in $(NON_CPPO_SOURCES); do \
	  echo ">>> $$f" ; \
	  ( opam exec -- ocp-indent "$$f" | diff "$$f" - ) || res=1 ; \
	done ; \
	exit $$res

test: unit-test integration-test

unit-test:
	opam exec -- dune runtest

define RUN_NOTEBOOK
	sed 's/__KERNEL_NAME__/$(KERNEL_NAME)/g' $(1) | OCAML_JUPYTER_LOG=$(OCAML_JUPYTER_LOG) jupyter nbconvert --to notebook --execute --stdin --output $(1:.ipynb=.nbconvert.ipynb)

endef

integration-test:
	$(foreach file, $(shell find tests/integration -name '*.ipynb' -not -name '*.nbconvert.ipynb' -not -path '*/.ipynb_checkpoints/*'), $(call RUN_NOTEBOOK,$(file)))
