defmodule Mix.Compilers.C do
  alias Mix.Compilers.C.Utils
  alias Mix.Compilers.C.Utils.EnvExpander

  defmodule Spec do
    defstruct type: :drv, target: "", sources: [], objects: [], opts: []
  end

  defmodule EnvExpansionError do
    @moduledoc """
    Raised when too many reductions have been made.
    This ususally means that an environment variable has been set to reference a non-existing env variable.
    """
    defexception [:message]
    def exception(value) do
      msg = "Too many env reductions. Leftovers: #{inspect value}"
      %EnvExpansionError{message: msg}
    end
  end


  def compile(spec, env, opts \\ []) do
    spec = %Spec{spec |
      :type => target_type(spec.target),
      :objects => source_objects(spec.sources)
    }
    envs = EnvExpander.expand([default_env, Map.to_list(System.get_env), env])
    # result = System.cmd("cc", [], [env: envs])
    Mix.shell.info "DEBUG: Compiling #{inspect spec}"
    bins = compile_files(spec.sources, spec.type, envs, [])

    template = select_link_template(spec.type)
    cmd = :proplists.get_value(template, envs)
      |> String.replace("{PORT_IN_FILES}", Enum.join(bins, " "))
      |> String.replace("{PORT_OUT_FILE}", spec.target)
    Mix.shell.info "DEBUG: Running cmd: #{cmd}"
    result = Mix.Shell.IO.cmd cmd
    Mix.shell.info result
  end

  defp compile_files([], _type, _env, bins) do
    bins
  end
  defp compile_files([file|rest], type, env, bins) do
    ext = Path.extname(file)
    bin = Path.rootname(file)<>".o"
    comp = compiler(ext)
    template = select_compile_template(type, comp)
    cmd = :proplists.get_value(template, env)
      |> String.replace("{PORT_IN_FILES}", file)
      |> String.replace("{PORT_OUT_FILE}", bin)
    Mix.shell.info "DEBUG: Running cmd: #{cmd}"
    result = Mix.Shell.IO.cmd cmd
    Mix.shell.info result
    compile_files(rest, type, env, bins++[bin])
  end

  defp select_compile_template(:drv, comp), do: select_compile_drv_template(comp)
  defp select_compile_template(:exe, comp), do: select_compile_exe_template(comp)

  defp select_compile_drv_template("$CC"), do: "DRV_CC_TEMPLATE"
  defp select_compile_drv_template("$CXX"), do: "DRV_CXX_TEMPLATE"

  defp select_compile_exe_template("$CC"), do: "EXE_CC_TEMPLATE"
  defp select_compile_exe_template("$CXX"), do: "EXE_CXX_TEMPLATE"

  defp select_link_template(:drv), do: "DRV_LINK_TEMPLATE"
  defp select_link_template(:exe), do: "EXE_LINK_TEMPLATE"

  def clean(spec) do
    File.rm(spec.target)
    source_objects(spec.sources) |> Enum.each(&File.rm/1)
    Mix.shell.info "Cleaning spec"
  end

  defp target_type(target) do
    case Path.extname(target) do
      ".so"  -> :drv
      ".dll" -> :drv
      ""     -> :exe
      ".exe" -> :exe
    end
  end


  defp compiler(".cc"),  do: "$CXX"
  defp compiler(".cp"),  do: "$CXX"
  defp compiler(".cxx"), do: "$CXX"
  defp compiler(".cpp"), do: "$CXX"
  defp compiler(".CPP"), do: "$CXX"
  defp compiler(".c++"), do: "$CXX"
  defp compiler(".C"),   do: "$CXX"
  defp compiler(_),      do: "$CC"

  defp source_objects(sources) do
    sources
      |> Stream.map(&(Path.rootname(&1)<>".o"))
      |> Enum.to_list
  end


  def default_env do
    [
      {"CC" , "cc"},
      {"CXX", "c++"},

      {"CFLAGS", ""},
      {"CXXFLAGS", ""},
      {"LDFLAGS", ""},

      {"DRV_CXX_TEMPLATE",
        "$CXX -c $CXXFLAGS $DRV_CFLAGS {PORT_IN_FILES} -o {PORT_OUT_FILE}"},
      {"DRV_CC_TEMPLATE",
        "$CC -c $CFLAGS $DRV_CFLAGS {PORT_IN_FILES} -o {PORT_OUT_FILE}"},
      {"DRV_LINK_TEMPLATE",
        "$CC {PORT_IN_FILES} $LDFLAGS $DRV_LDFLAGS -o {PORT_OUT_FILE}"},
      {"EXE_CXX_TEMPLATE",
        "$CXX -c $CXXFLAGS $EXE_CFLAGS {PORT_IN_FILES} -o {PORT_OUT_FILE}"},
      {"EXE_CC_TEMPLATE",
        "$CC -c $CFLAGS $EXE_CFLAGS {PORT_IN_FILES} -o {PORT_OUT_FILE}"},
      {"EXE_LINK_TEMPLATE",
        "$CC {PORT_IN_FILES} $LDFLAGS $EXE_LDFLAGS -o {PORT_OUT_FILE}"},
      {"DRV_CFLAGS" , "-g -Wall -fPIC -MMD $ERL_CFLAGS"},
      {"DRV_LDFLAGS", "-shared $ERL_LDFLAGS"},
      {"EXE_CFLAGS" , "-g -Wall -fPIC -MMD $ERL_CFLAGS"},
      {"EXE_LDFLAGS", "$ERL_LDFLAGS"},

      {"ERL_CFLAGS", ~s( -I"#{Utils.erl_interface_dir(:include)}" -I"#{Utils.erts_dir(:include)}")},
      {"ERL_EI_LIBDIR", ~s("#{Utils.erl_interface_dir(:lib)}")},
      {"ERL_LDFLAGS"  , " -L$ERL_EI_LIBDIR -lerl_interface -lei"},
      {"ERLANG_ARCH"  , Utils.wordsize},
      {"ERLANG_TARGET", Utils.get_arch},

      {~r/darwin/, "DRV_LDFLAGS",
        "-bundle -flat_namespace -undefined suppress $ERL_LDFLAGS"},

      # Solaris specific flags
      {~r/solaris.*-64$/, "CFLAGS", "-D_REENTRANT -m64 $CFLAGS"},
      {~r/solaris.*-64$/, "CXXFLAGS", "-D_REENTRANT -m64 $CXXFLAGS"},
      {~r/solaris.*-64$/, "LDFLAGS", "-m64 $LDFLAGS"},

      # Linux specific flags for multiarch
      {~r/linux.*-64$/, "CFLAGS", "-m64 $CFLAGS"},
      {~r/linux.*-64$/, "CXXFLAGS", "-m64 $CXXFLAGS"},
      {~r/linux.*-64$/, "LDFLAGS", "$LDFLAGS"},

      # OS X Leopard flags for 64-bit
      {~r/darwin9.*-64$/, "CFLAGS", "-m64 $CFLAGS"},
      {~r/darwin9.*-64$/, "CXXFLAGS", "-m64 $CXXFLAGS"},
      {~r/darwin9.*-64$/, "LDFLAGS", "-arch x86_64 $LDFLAGS"},

      # OS X Snow Leopard, Lion, and Mountain Lion flags for 32-bit
      {~r/darwin1[0-2].*-32/, "CFLAGS", "-m32 $CFLAGS"},
      {~r/darwin1[0-2].*-32/, "CXXFLAGS", "-m32 $CXXFLAGS"},
      {~r/darwin1[0-2].*-32/, "LDFLAGS", "-arch i386 $LDFLAGS"},

      # Windows specific flags
      # add MS Visual C++ support to rebar on Windows
      {~r/win32/, "CC", "cl.exe"},
      {~r/win32/, "CXX", "cl.exe"},
      {~r/win32/, "LINKER", "link.exe"},
      {~r/win32/, "DRV_CXX_TEMPLATE",
        # DRV_* and EXE_* Templates are identical
        "$CXX /c $CXXFLAGS $DRV_CFLAGS {PORT_IN_FILES} /Fo{PORT_OUT_FILE}"},
      {~r/win32/, "DRV_CC_TEMPLATE",
        "$CC /c $CFLAGS $DRV_CFLAGS {PORT_IN_FILES} /Fo{PORT_OUT_FILE}"},
      {~r/win32/, "DRV_LINK_TEMPLATE",
        "$LINKER {PORT_IN_FILES} $LDFLAGS $DRV_LDFLAGS /OUT:{PORT_OUT_FILE}"},
      # DRV_* and EXE_* Templates are identical
      {~r/win32/, "EXE_CXX_TEMPLATE",
        "$CXX /c $CXXFLAGS $EXE_CFLAGS {PORT_IN_FILES} /Fo{PORT_OUT_FILE}"},
      {~r/win32/, "EXE_CC_TEMPLATE",
        "$CC /c $CFLAGS $EXE_CFLAGS {PORT_IN_FILES} /Fo{PORT_OUT_FILE}"},
      {~r/win32/, "EXE_LINK_TEMPLATE",
       "$LINKER {PORT_IN_FILES} $LDFLAGS $EXE_LDFLAGS /OUT:{PORT_OUT_FILE}"},
      # ERL_CFLAGS are ok as -I even though strictly it should be /I
      {~r/win32/, "ERL_LDFLAGS", " /LIBPATH:$ERL_EI_LIBDIR erl_interface.lib ei.lib"},
      {~r/win32/, "DRV_CFLAGS", "/Zi /Wall $ERL_CFLAGS"},
      {~r/win32/, "DRV_LDFLAGS", "/DLL $ERL_LDFLAGS"}
    ]
  end

end
