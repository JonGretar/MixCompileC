defmodule Mix.Compilers.C.Utils.EnvExpander do
  alias Mix.Compilers.C.Utils
  alias Mix.Compilers.C.EnvExpansionError


  @spec expand(List.t) :: Map.t
  def expand(envs) do
    filtered = filter_env(List.flatten(envs))
    # Loop through expanding the envs. Give up if we have reduced 10 times the length of envs.
    expand_loop(merge(filtered), length(filtered)*10)
    # expand_loop(merge(filtered), 1)
  end

  # Loops over all the envs and expands them until no references are left
  defp expand_loop(queue, reductions, acc_map \\ %{})
  # defp expand_loop([], _count, map), do: map
  defp expand_loop([], _count, map), do: Enum.to_list(map)
  defp expand_loop(queue, 0, _map) do
    raise EnvExpansionError, queue
  end
  defp expand_loop([{key, value}|rest], reductions, map) do
    # Do map lookup and replacement.
    if String.contains?(value, "$") do
      keys = List.flatten Regex.scan(~r/\${?(\w+)}?/, value, capture: :all_but_first)
      expanded_value = expand_value_loop(keys, value, map)
      expand_loop(rest++[{key,expanded_value}], reductions-1, Map.put(map, key, expanded_value))
    else
      expand_loop(rest, reductions-1, Map.put(map, key, value))
    end
  end

  # Iterates and replaces the keys in a single value
  defp expand_value_loop([], value, _map), do: value
  defp expand_value_loop([key|rest], value, map) do
    case Map.get(map, key) do
      nil ->
        expand_value_loop(rest, value, map)
      replacement ->
        expand_value_loop(rest, expand_env_variable(value, key, replacement), map)
    end
  end

  # Merges together identical enviroments in an exanding manner
  def merge(in_vars, vars \\ %{})
  def merge([], map), do: Enum.to_list(map)
  def merge([{key, value}|rest], map) do
    evalue = case Map.get(map, key) do
     nil ->
       # Nothing yet defined for this key/value.
       # Expand any self-references as blank.
       expand_env_variable(value, key, "");
     value0 ->
      # Use previous definition in expansion
       expand_env_variable(value, key, value0)
    end
    merge(rest, Map.put(map, key, evalue))
  end

  # Does the actual string replacement on a value
  def expand_env_variable(source, var, value) do
    if String.contains?(source, "$") do
      Regex.replace(~r/\$(#{var}|{#{var}})/u, source, value)
    else
      source
    end
  end

  # Filters out envs for other ARCH types
  defp filter_env(envs, acc \\ [])
  defp filter_env([], acc), do: acc
  defp filter_env([{filter, key, val}|rest], acc) do
    if Utils.is_arch?(filter) do
      filter_env(rest, acc++[{key, val}])
    else
      filter_env(rest, acc)
    end
  end
  defp filter_env([{key, val}|rest], acc) do
    filter_env(rest, acc++[{key, val}])
  end


end
