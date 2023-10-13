defmodule FServerTest do
  use ExUnit.Case
  doctest FServer

  test "greets the world" do
    assert FServer.hello() == :world
  end
end
