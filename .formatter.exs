[
  inputs: ["mix.exs", ".formatter.exs", ".credo.exs", "{config,lib,test}/**/*.{ex,exs}"],
  locals_without_parens: [async: 1, async: 2],
  export: [locals_without_parens: [async: 1, async: 2]]
]
