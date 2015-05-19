defmodule Mix.Compilers.C.Utils do

  @doc """
  Generates a flat list of files from a pattern.
  """
  def flatten_files(map) do
    map
      |> Stream.map(&Path.wildcard/1)
      |> Stream.concat
      |> Enum.to_list
  end

  @doc """
  The the filesystem path to the erts library with an optional sub directory.
  """
  def erts_dir(subdir \\ "")
  def erts_dir(subdir) when is_atom(subdir), do: erts_dir(Atom.to_string(subdir))
  def erts_dir(subdir) do
    erts_dir = to_string(:code.root_dir)<>"/erts-"<>to_string(:erlang.system_info(:version))
    Path.join(erts_dir, subdir)
  end

  @doc """
  The the filesystem path to the erl_interface library with an optional sub directory.
  """
  def erl_interface_dir(subdir) do
    case :code.lib_dir(:erl_interface, subdir) do
      {:error, :bad_name} -> raise Error, message: "unable to find the erl_interface library"
      dir -> dir
    end
  end

  @doc """
  Check if a regex matches current arch.
  """
  def is_arch?(arch_regex) do
    Regex.match?(arch_regex, get_arch)
  end

  @doc """
  Get the full arch type.
  """
  def get_arch do
    otp_release<>"-"<>to_string(:erlang.system_info(:system_architecture))<>"-"<>wordsize()
  end

  @doc """
  Get the current systems word size.
  """
  def wordsize do
    try do
      Integer.to_string(8 * :erlang.system_info({:wordsize, :external}))
    rescue
      _ -> Integer.to_string(8 * :erlang.system_info(:wordsize))
    end
  end

  @doc """
  Get the Erlang/OTP release number.
  """
  def otp_release do
    # TODO This is mainly to be compatable with later changes.
    "R"<>to_string(:erlang.system_info(:otp_release))<>".X"
  end

end
