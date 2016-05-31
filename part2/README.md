Tutorial for simple Trading Card Game
=====================================

# Part 1: an example game between 2 computer opponents

## Rules of the game

Let's start a new project, it's up to you, but I'll call in TCG
(short for trading card game). Trading card games are games like
Magic of Gathering and Heartstone in which 2 players try to
`kill` each other using (monsters) cards.

Each players start with 30 life/health points, 0 points to spend and a deck of 30 cards.
Before each round a player draws a card and gets a new point to spend. The value of the
card determines the cost and damage. After each round the amount of points to spend are
replenished, so in round 1 you have 1 point, round 2 2 points etc.

When a player plays a card the health of the opponent is diminished by the value of the
card(s). First player which gets the opponents health to zero, wins.

## Start project

Elixir has a tool called `mix` which is used to run task (get dependencies, run test, start new project).
Let's start a new project:

`mix new tcg --module TCG`

This creates a folder tcg with some boilerplate code. To check if everything is ok, let's
follow mix' suggestion: `cd tcg && mix test`.

## Starting example app

To get a feeling for the needed steps, we'll create an example game. When started it will
spawn 2 AI(-like) players and run the game.

Open up `lib/example_game.ex` and add:

```
defmodule ExampleGame do
  use GenServer
  require Logger

  def start do
    GenServer.start __MODULE__, [], [name: :game]
  end

  def init([]) do
    {:ok, ["player1", "player2"]}
  end
end
```

We'll add a simple test as well in `test/example_game_test.exs`:
```
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
```

Now we have a simple GenServer process to start, which has a list
of two strings as it's state (__MODULE__ is a constant for the current module name, ExampleGame in our case).

After running `mix test` we'll see the first thing to fix.

## Requesting game state

Our first test tells us we need to implement `ExampleGame.current_players/0` function (the `/0` indicates it's a function of arity 0, expecting no arguments.

Let's go ahead and add it:

`def current_players, do: GenServer.call(:game, :players)`

After `mix test` the errors tell us our ExampleGame doesn't know
how to handle this call. The errors (at the bottom) tells us
what the last received message was + the current state.

Let's add a sample implementation for debugging:

```
def handle_call(:players, _from, players) do
  Logger.info players
  {:reply, players, players}
end
```

`mix test` should now be all green :)

## How does our Player model look like

Let's define a struct for a Player (`lib/player.ex`):

```
defmodule Player do
  @moduledoc "Player definition, for game state"
  @deck [0,0, 1,1, 2,2,2, 3,3,3,3, 4,4,4, 5,5, 6,6, 7, 8]

  defstruct name: "", health: 30, slots: 0, mana: 0, deck: @deck, hand: [], pid: nil

  def current_state(pid) do
    GenServer.call(pid, :player)
  end
end
```

Each player has:
  - it's own name
  - starts with 30 health points
  - 0 slots (this will increase each round)
  - 0 mana (amount of points left during a turn)
  - an empty deck of cards
  - an empty hand
  - a pid so our game with which process to communicate

## Let's start the game with 2 players

Change our ExampleGame.init/1 to:

```
def init([]) do
  names = names ["wizard", "gnome", "nerd", "dragonborn", "thiefling"]

  [name1, name2] = names |> Enum.shuffle |> Enum.take(2)
  Logger.info "Game starting with #{name1} and #{name2}"

  {:ok, player1_pid} = GenServer.start(AIPlayer, name1, [name: String.to_atom(name1)])
  {:ok, player2_pid} = GenServer.start(AIPlayer, name2, [name: String.to_atom(name2)])

  player1 = Player.current_state(player1_pid)
  player2 = Player.current_state(player2_pid)

  {:ok , [player1, player2]}
end
```

This starts 2 processes using AIPlayer module, which hasn't been defined yet (`lib/ai_player.ex`):

```
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
    Logger.info "I am #{name} (#{inspect self()})"
    {:ok, %Player{name: name, deck: Enum.shuffle(@deck), pid: self()}}
  end
end
```

And so it begins, we now have an Example game which starts two AI players (which currently don't do anything).

## On to the first turn

Change the ExampleGame.start/0 function, so we send ourselves a message
once the game in initialized:

```
def start do
  {:ok, pid} = GenServer.start __MODULE__, [], [name: :game]
  Process.send_after(pid, :first_turn, 3000)

  {:ok, pid}
end
```

A 'normal' message sendt to a GenServer will be handled by a `handle_info` callback:

```
def handle_info(:first_turn, players) do
  {:ok, players} = ExampleGame.first_turn(players)

  {:noreply, players}
end
```

which call `ExampleGame.first_turn/1`:

```
def first_turn([current_player, other_player] = players) do
  Logger.info "Gong for first round"
  Enum.each players, &(GenServer.call(&1.pid, :start_hand))
  updated_player1 = GenServer.call(current_player.pid, :start_turn)
  Logger.info "First players looks like #{inspect updated_player1}"
  {mana_left, cards_played, _} = GenServer.call(current_player.pid, :play_cards)
  Logger.info "First player played #{inspect cards_played}, and has #{mana_left} mana"
  updated_player2 = GenServer.call(other_player.pid, {:damage, Enum.reduce(cards_played, 0, &+/2)})
  Process.send_after(:game, :next_turn, 2000)

  {:ok, [updated_player1, updated_player2]}
end
```

ExampleGame will ask both players to populate it's hand with 3 cards as a starting point. After that it asks the current player to start it's turn (increase mana slot, replenish mana and take a card from deck).
Next it will ask the current player to choose cards to play against opponent. The opponent will get notified about received damage.
ExampleGame shedules the next round in 2 sec and return the current state of both players.


# Next turn

Near the end of the first turn we send ourselves a message to start the next round. That message is going to be handled by this `handle_info` (in `lib/example_game.ex`):

```
def handle_info(:next_turn, [other_player, current_player]) do
  Logger.info "Starting next round with #{inspect other_player}"
  updated_player1 = GenServer.call(current_player.pid, :start_turn)
  Logger.info "Current player looks like #{inspect updated_player1}"
  {_mana_left, played_cards, _hand_left} = GenServer.call(current_player.pid, :play_cards)
  Logger.info "#{updated_player1.name} played #{inspect played_cards}"
  updated_player2 = GenServer.call(other_player.pid, {:damage, Enum.reduce(played_cards, 0, &+/2)})
  proceed_or_declare_winner(updated_player1, updated_player2)
end
```

It's very much the same as first round, except now we're checking if the game has ended at the end of our function.

```
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
```

This is basically everything our ExampleGame needs:
- a start
- first turn
- next turn, until there's a winner

## Finishing AI player

The AI player needs to respond to a few messages:

- responding to state requests
- start hand (taking 3 cards from deck in hand)
- start turn (increasing mana slots, refresh mana, take a card from deck)
- play cards from hand
- take damage and die when time comes
- receive a compliment when the game has been won

This looks like `lib/ai_player.ex`:

```
def handle_call(:player, _from, player), do: {:reply, player, player}

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

def handle_cast(:winner, player) do
  Logger.info "Yes, the great #{player.name} has won, hooray!"

  {:stop, :normal, player}
end
```

## A small test of our AI

FP has a promise of easily testing, so let's add a minor test to see
if our AI player works as intended (`test/ai_player_test.exs`)

```
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
```

# Part 2: a single player game

## A CLI for our human player

Now that we have an example in place, let's create an cli interface for a human player. It strongly resembles AI player, with the biggest difference of choosing which cards to play. Pay attention to the choose_card(s) functions.

`lib/cli.ex` looks like:

```
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
```

## A new game

The example game starts 2 AI player automatically, let's create a game version which start with 2 given players:

`lib/game.ex`:

```
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

```

## Let's play a game

Fire up iex (if you haven't already): `iex -S mix`
Start an AI player: `{:ok, ai_pid} = AIPlayer.start "DeepBlue"`
Start our CLI: `{:ok, cli_pid} = Cli.start` (we'll be asked for a name)

Start the game with 2 players: `{:ok, game_pid} = Game.start([cli_pid, ai_pid])`


# Done!

Congratulations, you're at the end of this tutorial.
It's now up to you to decide how to expand on this game.
If you need inspiration, check Followup.md, but make sure you have
a small plan of attack, since we're short on time: keep it small.
