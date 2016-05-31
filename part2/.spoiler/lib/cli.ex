defmodule Cli do
  use GenServer
  require Player
  require Logger

  @moduledoc "Our CLI interface to human player"

  def start do
    name = "What is your name?"
      |> IO.gets
      |> String.slice(0..-2)

    GenServer.start __MODULE__, name, []
  end

  def init(name) do
    {:ok, %Player{name: name,  pid: self()}}
  end

  def main(_args) do
    names = ["wizard", "gnome", "nerd", "dragonborn", "thiefling"]
    {:ok, human_pid} = Cli.start
    {:ok, cpu_pid} = AIPlayer.start Enum.random(names)
    {:ok, game_pid} = Game.start([human_pid, cpu_pid])
  end

  def handle_call(:player, _from, player) do
    {:reply, player, player}
  end

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
    {hand, deck} = Enum.split player.deck, 1
    new_player = %Player{player | deck: deck, hand:   player.hand ++ hand, slots: player.slots + 1, mana: player.slots + 1}

    {:reply, new_player, new_player}
  end

  def handle_call(:play_cards, _from, player) do
    {new_player, played} = choose_cards(player, [])

    {:reply, {new_player.mana, played, new_player}, new_player}
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

  defp choose_cards(player, chosen_card_list) do
    IO.puts "You have #{player.mana}, choose the cards you want to play"
    index = player.hand
      |> choose_list
      |> IO.gets
      |> String.slice(0..-2)
      |> String.to_integer

    choose_cards(player, chosen_card_list, index)
  end

  defp choose_cards(player, chosen_card_list, 0), do: {player, chosen_card_list}

  defp choose_cards(player, chosen_card_list, index) when index > 0 do
    chosen_card = Enum.at(player.hand, index - 1)
    rest_hand = List.delete player.hand, chosen_card

    mana_left = player.mana - chosen_card
    case mana_left do
      x when x > 0 ->
        choose_cards(%Player{player| mana: mana_left, hand: rest_hand}, [chosen_card | chosen_card_list])
      x when x == 0 ->
        {%Player{player| mana: mana_left, hand: rest_hand}, [chosen_card | chosen_card_list]}
      x when x < 0 ->
        IO.puts "Not enough mana for this card, please choose another"
        choose_cards(player, chosen_card_list)
    end
  end

  defp choose_cards(player, chosen_card_list, _) do
    IO.puts "Invalid input, try again"
    choose_cards(player, chosen_card_list)
  end

  @doc """
  Function to turn cards in hand into an option list

  ## Examples
    iex(10)> Cli.choose_list [1, 3, 2, 7]
    "1: 1\n2: 3\n3: 2\n4: 7"
  """
  @spec choose_list(list) :: binary
  def choose_list(cards) do
    cards
    |> Enum.with_index(1)
    |> Enum.map(fn({card, index}) -> "#{index}: #{card}" end)
    |> Enum.join("\n")
  end
end

