defmodule ExampleGame do
  use GenServer
  require Logger
  @moduledoc """
  Module which functions as game master: assigning turns,
  enforcing rules, declaring winners etc
  """

  @names ["wizard", "gnome", "nerd", "dragonborn", "thiefling"]
  # public api
  def start do
    {:ok, pid} = GenServer.start __MODULE__, [], [name: :game]
    Process.send_after(pid, :first_turn, 3000)

    {:ok, pid}
  end

  def current_players, do: GenServer.call(:game, :players)

  def first_turn([current_player, other_player] = players) do
    Logger.info "Gong for first round"
    Logger.info "Game is now #{inspect Process.whereis(:game)}"
    Logger.info "Starting first round"
    Enum.each players, &(GenServer.call(&1.pid, :start_hand))
    updated_player1 = GenServer.call(current_player.pid, :start_turn)
    Logger.info "First players looks like #{inspect updated_player1}"
    {mana_left, cards_played, _} = GenServer.call(current_player.pid, :play_cards)
    Logger.info "First player played #{inspect cards_played}, and has #{mana_left} mana"
    updated_player2 = GenServer.call(other_player.pid, {:damage, Enum.reduce(cards_played, 0, &+/2)})
    Process.send_after(:game, :next_turn, 2000)

    {:ok, [updated_player1, updated_player2]}
  end

  # callback
  def init([]) do

    [name1, name2] = @names |> Enum.shuffle |> Enum.take(2)
    Logger.info "Game started with #{name1} and #{name2}"

    {:ok, player1_pid} = GenServer.start(AIPlayer, name1, [name: String.to_atom(name1)])
    {:ok, player2_pid} = GenServer.start(AIPlayer, name2, [name: String.to_atom(name2)])

    player1 = Player.current_state(player1_pid)
    player2 = Player.current_state(player2_pid)

    {:ok , [player1, player2]}
  end

  def init([player1, player2]), do: {:ok , [player1, player2]}

  def handle_call(:players, _from, players) do
    Logger.info inspect players
    {:reply, players, players}
  end

  def handle_call(command, from, state) do
    Logger.info ["Received #{inspect command}", "From #{inspect from}", "Current state #{inspect state}"]
    {:reply, state, state}
  end

  def handle_info(:next_turn, [other_player, current_player]) do
    Logger.info "Starting next round with #{inspect other_player}"
    updated_player1 = GenServer.call(current_player.pid, :start_turn)
    Logger.info "Current player looks like #{inspect updated_player1}"
    {_mana_left, played_cards, _hand_left} = GenServer.call(current_player.pid, :play_cards)
    Logger.info "#{updated_player1.name} played #{inspect played_cards}"
    updated_player2 = GenServer.call(other_player.pid, {:damage, Enum.reduce(played_cards, 0, &+/2)})
    proceed_or_declare_winner(updated_player1, updated_player2)
  end

  def handle_info(:first_turn, players) do
    Logger.info "Ok, game is a start"
    {:ok, players} = ExampleGame.first_turn(players)

    {:noreply, players}
  end

  def handle_info(command, state) do
    Logger.info ["Received #{inspect command}", "Current state #{inspect state}"]
    {:noreply, state}
  end

  defp proceed_or_declare_winner(current_player, other_player) do
    case other_player.health do
      x when x < 1 ->
        Logger.info "Ouch, #{other_player.name} has died, health is now #{x}"
        GenServer.cast(current_player.pid, :winner)

        result = %{state: :game_over, winner: current_player, loser: other_player}
        Logger.info "Aaaaannnd the winner is ... #{result.winner.name}, unfortunately for #{result.loser.name}"

        {:stop, :normal, result}
      _ ->
        Process.send_after(:game, :next_turn, 2000)

        {:noreply, [current_player, other_player]}
    end
  end
end
