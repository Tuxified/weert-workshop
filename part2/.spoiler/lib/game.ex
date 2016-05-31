defmodule Game do
  use GenServer
  require Logger
  require Player
  @moduledoc """
  Module which functions as game master: assigning turns,
  enforcing rules, declaring winners etc
  """

  # public api
  def start([player1_pid, player2_pid]) when is_pid(player1_pid) do
    player1 = Player.current_state player1_pid
    player2 = Player.current_state player2_pid

    {:ok, pid} = GenServer.start_link __MODULE__, [player1, player2], []
    Process.send_after(pid, :first_turn, 3000)

    {:ok, pid}
  end

  def start([player1, player2]) do
    {:ok, pid} = GenServer.start_link __MODULE__, [player1, player2], []
    Process.send_after(pid, :first_turn, 3000)

    {:ok, pid}
  end

  @spec current_players(pid) :: list(%Player{})
  def current_players(pid) do
    GenServer.call(pid, :players)
  end

  @spec first_turn(list(%Player{})) :: {:ok, list(%Player{}), list(%Player{})}
  def first_turn(players) do
    Logger.info "Gong for first round"
    Enum.each players, &(deal_hand(&1))
    [updated_player1, updated_player2] = do_turn(players)
    Process.send_after(self, :next_turn, 2000)

    {:ok, [updated_player1, updated_player2], [updated_player1, updated_player2]}
  end

  @spec do_turn(list(%Player{})) :: list(%Player{})
  def do_turn([current_player, other_player]) do
    updated_player1 = GenServer.call(current_player.pid, :start_turn)
    Logger.info "First players looks like #{inspect updated_player1}"
    {mana_left, cards_played, _} = GenServer.call(current_player.pid, :play_cards, 60_000)
    Logger.info "First player played #{inspect cards_played}, and has #{mana_left} mana"
    updated_player2 = GenServer.call(other_player.pid, {:damage, Enum.reduce(cards_played, 0, &+/2)})

    [updated_player1, updated_player2]
  end

  # callback
  def init([player1, player2]) do
    Logger.info "Game started with #{player1.name} and #{player2.name}"
   {:ok , [player1, player2]}
  end

  def handle_call(:players, _from, players) do
    Logger.info inspect players
    {:reply, players, players}
  end

  @spec handle_info(:next_turn, list(%Player{})) :: {:stop, :normal, %{}} | {:noreply, list(%Player{})}
  def handle_info(:next_turn, [other_player, current_player]) do
    Logger.info "Starting next round with #{inspect other_player}"
    [updated_player1, updated_player2] = do_turn([current_player, other_player])

    proceed_or_declare_winner(updated_player1, updated_player2)
  end

  @spec handle_info(:first_turn, list(%Player{})) :: {:noreply, list(%Player{})}
  def handle_info(:first_turn, players) do
    Logger.info "Ok, game is a start"
    {:ok, _players, players_pids} = Game.first_turn(players)

    {:noreply, players_pids}
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
        Process.send_after(self, :next_turn, 2000)

        {:noreply, [current_player, other_player]}
    end
  end

  defp deal_hand(%Player{} = player) do
    {hand, deck} = Enum.split(player.deck, 3)
    GenServer.call(player.pid, {:start_hand, hand, deck})
  end
end
