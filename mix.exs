defmodule MixPortCompiler.Mixfile do
  use Mix.Project

  def project do
    [
      app: :mix_compile_c,
      version: "0.0.1",
      elixir: "~> 1.0",
      deps: deps,
      # compilers: Mix.compilers ++ [:c],
      c_src: c_src
    ]
  end

  defp c_src do
    [
      specs: [
        {"priv/nif.so", ["c_src/hello_nif/*.c"]},
        {"priv/bitcask.so", ["c_src/bitcask/*.c"]},
        # {~r/win32/, "priv/port.exe", ["c_src/*.c"]},
        # {~r/darwin/, "priv/port", ["c_src/*.c"]}
      ],
      env: [
        {"DRV_CFLAGS", "-g -Wall -fPIC -MMD $ERL_CFLAGS"}
      ]
    ]
  end

  def application do
    [applications: []]
  end

  defp deps do
    []
  end
end
