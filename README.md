Mix Compile C
===============


## Preview Version

This is preview level code and not released to hex yet. To try it check out the library to a path somewhere and use the
`:path` attribute when adding the dep.

There are multiple things wrong with current iteration.


## Usage

First, add the project to your mix.exs dependencies:

```elixir
def deps do
  [{:mix_compile_c, "~> 0.0.1", path: "/Users/USER/Code/MixCompileC"}]
end
```

Then add `:c` to your list of compilers and set up your `c_src`.

```elixir
def project do
  [
    app: :my_project,
    version: "0.0.1",
    elixir: "~> 1.0",
    deps: deps,
    compilers: Mix.compilers ++ [:c],
    c_src: c_src
  ]
end

defp c_src do
  [
    specs: [
      {"priv/project_port.so", ["c_src/*.c"]}
    ],
    env: []
  ]
end
```

### c_src.specs

Specs define c projects to compile.

```elixir
specs: [
  {"priv/project_port.so", ["c_src/*.c"]}
  {~r/win32/, "priv/project_port.so", ["c_src/windows/*.c"]}
],
```

The file extension will define the compilation steps taken.
".so" or ".dll" will be compiled as linked in drivers.
"" or ".exe" will be compiled as ports.

### c_src.env

Make changes to compile variables.

```elixir
env: [
  {~r/darwin/, "CFLAGS", "$CFLAGS -Wall"}
]
```

A list of current attributes can be found at:
https://github.com/JonGretar/MixCompileC/blob/master/lib/mix.compilers.ex#L100
