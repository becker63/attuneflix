; Keep these captures close to Flix's own syntax: Tree-sitter supplies lexical
; color immediately while `flix lsp` supplies semantic editor behavior.

(lower_id) @variable
(upper_id) @type
(wildcard) @variable.builtin

[(line_comment) (block_comment)] @comment
(doc_comment) @comment.documentation

[(int_literal) (float_literal)] @number
(char_literal) @character
[(string_literal) (debug_string_literal)] @string
(regex_string_literal) @string.regexp
(escape_sequence) @string.escape
(boolean_literal) @boolean
(unit_literal) @constant.builtin
(hole) @comment.error
(intrinsic) @function.builtin

[
  "mod" "def" "redef" "enum" "case" "struct" "type" "alias" "trait"
  "instance" "eff" "law" "use" "import" "with" "where" "handler"
] @keyword

[
  "pub" "sealed" "lawful" "static" "override" "inline" "mut" "opaque"
  "restrictable"
] @keyword.modifier

[
  "if" "else" "match" "typematch" "ematch" "choose" "choose*" "foreach"
  "forM" "forA" "yield" "forall"
] @keyword.conditional

[
  "let" "region" "spawn" "par" "run" "try" "catch" "throw" "select"
  "force" "lazy" "discard" "unsafe" "new" "open_variant" "xvar"
  "solve" "psolve" "query" "pquery" "inject" "project" "from" "into" "fix"
] @keyword

[(op_mul) (op_add) (op_cmp) (op_eq) (op_and) (op_or) (op_dollar)] @operator
["::" ":::" "->" "=>" "<-" "\\" "=" "+" "-" "&" "~"] @operator
[";" "," "." ":"] @punctuation.delimiter
["(" ")" "[" "]" "{" "}" "#{"] @punctuation.bracket

(annotation (annotation_name) @attribute)
(kind_identifier) @type.builtin
(type_name (qualified_name (upper_id) @type))
(schema_predicate name: (upper_id) @type)
(predicate_atom name: (upper_id) @type)

(enum_declaration name: (upper_id) @type)
(struct_declaration name: (upper_id) @type)
(type_alias_declaration name: (upper_id) @type)
(trait_declaration name: (upper_id) @type)
(effect_declaration name: (upper_id) @type.effect)
(module_declaration name: (qualified_name (upper_id) @module))

(type_parameter name: (lower_id) @type.parameter)
(formal_parameter name: (lower_id) @variable.parameter)
(named_argument name: (lower_id) @variable.parameter)
(struct_field name: (lower_id) @property)
(record_field label: (lower_id) @property)
(member_access_expression member: (lower_id) @property)

(enum_case name: (upper_id) @constructor)
(variant_case name: (upper_id) @constructor)
(tag_pattern name: (qualified_name (upper_id) @constructor .))

(application_expression
  function: (qualified_name (lower_id) @function.call .))
(def_declaration name: (lower_id) @function)
(local_def_expression name: (lower_id) @function)
(handler_def name: (lower_id) @function)
(law_declaration name: (lower_id) @function)

(effect_annotation
  (qualified_name [(upper_id) (lower_id)] @type.effect))
(effect_set
  (qualified_name [(upper_id) (lower_id)] @type.effect))

((upper_id) @type.builtin
  (#any-of? @type.builtin
    "Unit" "Bool" "Char" "Float32" "Float64" "Int8" "Int16" "Int32"
    "Int64" "BigInt" "BigDecimal" "String" "Region"))

((upper_id) @constant.builtin
  (#any-of? @constant.builtin
    "Nil" "Some" "None" "Ok" "Err" "LessThan" "EqualTo" "GreaterThan"))
