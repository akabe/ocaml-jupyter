// CodeMirror, copyright (c) by Marijn Haverbeke and others
// Distributed under an MIT license: http://codemirror.net/LICENSE

// "ocaml" mode is based on
//   https://github.com/codemirror/CodeMirror/blob/master/mode/mllike/mllike.js
// according to the definitions of OCaml tokens
//   https://github.com/ocaml/ocaml/blob/trunk/parsing/lexer.mll

(function() {
  var CodeMirror = window.CodeMirror;

  var words = {
	'as': 'keyword',
	'assert': 'keyword',
	'begin': 'keyword',
	'class': 'keyword',
	'constraint': 'keyword',
	'do': 'keyword',
	'done': 'keyword',
	'downto': 'keyword',
	'else': 'keyword',
	'end': 'keyword',
	'exception': 'keyword',
	'external': 'keyword',
	'for': 'keyword',
	'fun': 'keyword',
	'function': 'keyword',
	'functor': 'keyword',
	'if': 'keyword',
	'in': 'keyword',
	'include': 'keyword',
	'inherit': 'keyword',
	'initializer': 'keyword',
	'lazy': 'keyword',
	'let': 'keyword',
	'match': 'keyword',
	'method': 'keyword',
	'module': 'keyword',
	'mutable': 'keyword',
	'new': 'keyword',
	'nonrec': 'keyword',
	'object': 'keyword',
	'of': 'keyword',
	'open': 'keyword',
	'private': 'keyword',
	'rec': 'keyword',
	'sig': 'keyword',
	'struct': 'keyword',
	'then': 'keyword',
	'to': 'keyword',
	'try': 'keyword',
	'type': 'keyword',
	'val': 'keyword',
	'virtual': 'keyword',
	'when': 'keyword',
	'while': 'keyword',
	'with': 'keyword',
	'lor': 'operator',
	'lxor': 'operator',
	'land': 'operator',
	'lsl': 'operator',
	'lsr': 'operator',
	'asr': 'operator',
	'or': 'operator',
	'and': 'operator',
	'raise': 'builtin',
	'exit': 'builtin',
	'succ': 'builtin',
	'pred': 'builtin',
	'ignore': 'builtin',
	'failwith': 'builtin',
	'invalid_arg': 'builtin',
	'false': 'atom',
	'true': 'atom',
  };

  CodeMirror.defineMode('ocaml', function() {
	function tokenBase(stream, state) {
	  var ch = stream.next();

	  if (ch === ';') {
		if (stream.eat(';')) {
		  state.topdir = true;
		  return null;
		}
	  }

	  if (ch === '"') {
		state.tokenize = tokenString;
		state.topdir = false;
		return state.tokenize(stream, state);
	  }
	  if (ch === '{') {
		if (stream.eat('|')) {
		  state.tokenize = tokenLongString;
		  state.topdir = false;
		  return state.tokenize(stream, state);
		}
	  }
	  if (ch === '(') {
		if (stream.eat('*')) {
		  state.commentLevel++;
		  state.tokenize = tokenComment;
		  return state.tokenize(stream, state);
		}
	  }
	  if (ch === '`') { // polymorphic variant constructors
		stream.eatWhile(/\w\'/);
		state.topdir = false;
		return 'variable-2';
	  }
	  if (/[A-Z]/.test(ch)) { // variant constructors or modules
		stream.eatWhile(/[\w\']/);
		state.topdir = false;
		return 'variable-2';
	  }
	  if (/[a-z_]/.test(ch)) { // lower identifiers
		stream.eatWhile(/[\w\']/);
		state.topdir = false;
		var cur = stream.current();
		return words.hasOwnProperty(cur) ? words[cur] : 'variable';
	  }
	  if (/\d/.test(ch)) {
		stream.eatWhile(/[\w]/);
		if (stream.eat('.')) {
		  stream.eatWhile(/[\w]/);
		  if (stream.eat(/[eE]/)) {
			stream.eat(/[+-]/);
			stream.eatWhile(/[\d]/);
		  }
		}
		state.topdir = false;
		return 'number';
	  }
	  if (ch === '#' && state.topdir) {
		if (stream.eatWhile(/[\w]/)) {
		  state.topdir = false;
		  return 'atom';
		}
	  }
	  if (/[!$%&*+\-/~?<=>|@^#]/.test(ch)) {
		stream.eatWhile(/[!$%&*+\-/~?<=>|@^:\.]/);
		state.topdir = false;
		return 'operator';
	  }
	  return null;
	}

	function tokenString(stream, state) {
	  var next, end = false, escaped = false;
	  while ((next = stream.next()) != null) {
		if (next === '"' && !escaped) {
		  end = true;
		  break;
		}
		escaped = !escaped && next === '\\';
	  }
	  if (end && !escaped) {
		state.tokenize = tokenBase;
	  }
	  return 'string';
	}

	function tokenLongString(stream, state) {
	  var prev, next;
	  while((next = stream.next()) != null) {
		if (prev === '|' && next === '}') {
		  state.tokenize = tokenBase;
		  break;
		}
		prev = next;
	  }
	  return 'string';
	}

	function tokenComment(stream, state) {
	  var prev, next;
	  while(state.commentLevel > 0 && (next = stream.next()) != null) {
		if (prev === '(' && next === '*') state.commentLevel++;
		if (prev === '*' && next === ')') state.commentLevel--;
		prev = next;
	  }
	  if (state.commentLevel <= 0) {
		state.tokenize = tokenBase;
	  }
	  return 'comment';
	}

	return {
	  startState: function() {
		return {
		  tokenize: tokenBase,
		  commentLevel: 0,
		  topdir: true
		};
	  },
	  token: function(stream, state) {
		if (stream.eatSpace()) return null;
		return state.tokenize(stream, state);
	  },
	  blockCommentStart: "(*",
	  blockCommentEnd: "*)",
	  lineComment: null
	};
  });

  CodeMirror.defineMIME('text/x-ocaml', 'ocaml');
})();
