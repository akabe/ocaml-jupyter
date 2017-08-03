// ocaml-jupyter --- An OCaml kernel for Jupyter
//
// Copyright (c) 2017 Akinori ABE
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

define([
  'base/js/namespace',
  'nbextensions/ocaml-theme/ocaml-mode'
], function(Jupyter) {

  function load_notebook_extension() {

	var language = Jupyter.notebook.metadata.kernelspec.language.toLowerCase(); // get kernel info
	if (language == 'ocaml') {
	  // Set the default CodeMirror config.
	  var cm_config = Jupyter.CodeCell.options_default.cm_config;
	  if (!cm_config.indentUnit) {
		cm_config.indentUnit = 2;
		cm_config.lineNumbers = true;
	  }

	  // Overwrite settings of existing cells.
	  var cells = Jupyter.notebook.get_cells();
	  for (var i in cells) {
		var c = cells[i];
		if (c.cell_type == 'code') {
		  c.code_mirror.setOption('indentUnit', cm_config.indentUnit);
		  c.code_mirror.setOption('lineNumbers', cm_config.lineNumbers);
		}
	  }

	  // replace the logo image (https://github.com/ocaml/ocaml-logo)
	  var img = $('.container img')[0];
	  img.src = '/nbextensions/ocaml-theme/ocaml-logo.png';
	}
  }

  return {
    load_ipython_extension: load_notebook_extension
  };
});
