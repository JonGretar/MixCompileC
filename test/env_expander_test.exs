defmodule EnvExpanderTest do
  use ExUnit.Case
  alias Mix.Compilers.C.Utils.EnvExpander, as: E

  test "Should return the same when there is nothing to expand" do
    assert E.expand([]) == []
    assert E.expand([{"KEY", "value"}]) == [{"KEY", "value"}]
  end

  test "Last should take precendence" do
    assert E.expand([{"FOO", "World"}, {"FOO", "Bar"}]) == [{"FOO", "Bar"}]
  end

  test "Should merge circular references" do
    input = [{"FOO", "Hello"}, {"FOO", "$FOO World"}, {"FOO", "Simon Says: $FOO"}]
    assert E.expand(input) == [{"FOO", "Simon Says: Hello World"}]
  end

  test "Should filter out stuff with wrong arch" do
    input = [
      {"FOO", "bar"},
      {~r/no_such_os-64/, "FOO", "omg"},
      {"HELLO", "world"}
    ]
    assert E.expand(input) == [{"FOO", "bar"}, {"HELLO", "world"}]
  end

  test "Should expand references" do
    input = [
      {"ENV1", "1"},
      {"MIDDLE", "$ENV1 comes before $ENV2"},
      {"ENV2", "2"},
      {"LINE", "Remember that $MIDDLE"}
    ]
    output = [
      {"ENV1", "1"}, {"ENV2", "2"},
      {"LINE", "Remember that 1 comes before 2"},
      {"MIDDLE", "1 comes before 2"}
    ]
    assert E.expand(input) == output
  end


end
