defmodule GameTest do
  use ExUnit.Case
  doctest Game

  defp example_player do
    :timer.sleep 2000
  end

  setup do
    {:ok, pid} = Game.start_link([%{pid: spawn(&example_player/0), name: "First"}, %{pid: spawn(&example_player/0), name: "Second"}])
    {:ok, game: pid}
  end

  test "game starts with 2 players", %{game: game} do
    assert Enum.count(Game.current_players(game)) == 2
  end
end
