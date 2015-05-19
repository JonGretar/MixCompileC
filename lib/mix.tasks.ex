# Code.ensure_loaded(Mix.Compilers.C.Utils)
# Code.ensure_loaded(Mix.Compilers.C.Spec)
defmodule Mix.Tasks.Compile.C do
  alias Mix.Compilers.C.Utils
  alias Mix.Compilers.C.Spec
  use Mix.Task
  @shortdoc "Compiles Ports and NIFs"

  def run(_) do
    config = Mix.Project.config[:c_src] || []
    specs = make_specs(config[:specs] || [])
    env = config[:env] || []
    specs |> Enum.each(&(Mix.Compilers.C.compile(&1, env)))
  end

  def clean do
    # TODO: Make sure cleaning works
    config = Mix.Project.config[:c_src] || []
    specs = make_specs(config[:specs] || [])
    specs |> Enum.each(&(Mix.Compilers.C.clean(&1)))
    Mix.shell.info "CLEANING"
  end

  defp make_specs(specs, acc \\ [])
  defp make_specs([], acc), do: acc
  defp make_specs([{target, source_map}|rest], acc) do
    sources = Utils.flatten_files(source_map)
    make_specs(rest, acc++[%Spec{target: target, sources: sources}])
  end
  defp make_specs([{filter, target, source_map}|rest], acc) do
    if Utils.is_arch?(filter) do
      sources = Utils.flatten_files(source_map)
      make_specs(rest, acc++[%Spec{target: target, sources: sources}])
    else
      make_specs(rest, acc)
    end
  end
end
