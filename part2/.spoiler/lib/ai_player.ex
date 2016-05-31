defmodule AIPlayer do
  use GenServer
  require Player
  require Logger

  @moduledoc """
  Example Player, currently simple AI
  """

  @deck [0,0, 1,1, 2,2,2, 3,3,3,3, 4,4,4, 5,5, 6,6, 7, 8]

  def start(name), do: GenServer.start __MODULE__, name, []

  def init(name) do
    Logger.info "Init got: #{inspect name}"
    Logger.info "I am #{inspect self()}"
    {:ok, %Player{name: name, deck: Enum.shuffle(@deck), pid: self()}}
  end

  def handle_call(:player, _from, player), do: {:reply, player, player}

  def handle_call({:damage, points}, from, player) do
    new_player = %Player{player | health: player.health - points}
    case new_player.health do
      x when x < 1 ->
        Logger.info "Aaargh, the great #{player.name} has lost, alas :'("
        GenServer.reply(from, new_player) # reply first before we terminate
        {:stop, :normal, new_player}
      _ ->
        {:reply, new_player, new_player}
    end
  end

  def handle_call(:start_hand, _from, player) do
    {hand, deck} = Enum.split(player.deck, 3)
    new_player = %Player{player | hand: hand, deck: deck}
    {:reply, new_player, new_player}
  end

  def handle_call(:start_turn, _from, player) do
    new_player = %Player{player | slots: player.slots + 1, mana: player.slots + 1}
    {hand, deck} = Enum.split new_player.deck, 1
    new_player = %Player{new_player | deck: deck, hand: new_player.hand ++ hand}
    {:reply, new_player, new_player}
  end

  def handle_call(:play_cards, _from, player) do
    {mana_left, _, hand_left} = played = Enum.reduce(player.hand, {player.mana, [], []}, fn(card, {mana, cards, hand}) ->
      case mana >= card do
        true -> {mana - card, [card | cards], hand}
        _    -> {mana, cards, [card | hand]}
      end
    end)

    new_player = %Player{player | hand: hand_left, mana: mana_left}
    {:reply, played, new_player}
  end

  def handle_call(:end_turn, _from, player) do
    {:reply, player, player}
  end

  def handle_call(command, _from, state) do
    Logger.info ["Received #{inspect command}", "Current state #{inspect state}"]

    {:reply, state, state}
  end

  def handle_cast(:winner, player) do
    Logger.info "Yes, the great #{player.name} has won, hooray!"

    {:stop, :normal, player}
  end

  def handle_cast(:loser, player) do
    Logger.info "Aaargh, the great #{player.name} has lost, alas :'("

    {:stop, :normal, player}
  end
end
