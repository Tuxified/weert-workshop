defmodule ExampleGameTest do
  use ExUnit.Case
  doctest ExampleGame

  setup do
    {:ok, pid} = ExampleGame.start
    {:ok, game: pid}
  end

  test "game starts with 2 players", %{game: _game} do
    assert Enum.count(ExampleGame.current_players) == 2
  end
end
