defmodule AIPlayerTest do
  use ExUnit.Case
  doctest AIPlayer

  setup do
    player_before = %Player{health: 5, hand: [1, 2, 5], mana: 6, slots: 6}
    player_after = %Player{player_before | health: 3}
    {:ok, player: player_before, damaged_player: player_after}
  end

  test "can take a hit", %{player: player, damaged_player: damaged_player} do
    assert AIPlayer.handle_call({:damage, 2}, "test", player) == {:reply, damaged_player, damaged_player}
  end

  test "chooses first cards, not best ones", %{player: player} do
    assert AIPlayer.handle_call(:play_cards, "test", player) == {:reply, {3, [2, 1], [5]}, %Player{player | hand: [5], mana: 3}}
  end
end
