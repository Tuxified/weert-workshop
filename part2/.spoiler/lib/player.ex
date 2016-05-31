defmodule Player do
  @moduledoc "Player definition, for game state"
  @deck [0,0, 1,1, 2,2,2, 3,3,3,3, 4,4,4, 5,5, 6,6, 7, 8]

  defstruct name: "", health: 30, slots: 0, mana: 0, deck: Enum.shuffle(@deck), hand: [], pid: self()

  def current_state(pid) do
    GenServer.call(pid, :player)
  end
end
