defmodule FunboxQtElixir.AwesomeServerTest do
  use FunboxQtElixir.AwesomeCase

  test "Starting AwesomeServer" do
    {ok_var, _pid} = FunboxQtElixir.AwesomeServer.start_link({:start})
    assert ok_var == :ok
  end

  test "Starting AwesomeServer from init/1" do
    {ok_var, _pid} = FunboxQtElixir.AwesomeServer.init({:start})
    assert ok_var == :ok
  end

  test "Geting all state" do
    min_stars = 0
    FunboxQtElixir.AwesomeServer.start_link({:start})
    result = FunboxQtElixir.AwesomeServer.get_awesome_list(min_stars)
    %{categories: categories, all_packs: all_packs} = result

    assert is_list(categories) == true
    assert is_list(all_packs) == true
  end

  test "Geting state with over 10 stars" do
    min_stars = 10
    FunboxQtElixir.AwesomeServer.start_link({:start})
    result = FunboxQtElixir.AwesomeServer.get_awesome_list(min_stars)
    %{categories: categories, all_packs: all_packs} = result

    assert is_list(categories) == true
    assert is_list(all_packs) == true
  end

  test "Updating packages 1" do
    assert FunboxQtElixir.AwesomeServer.update_packs(1, []) == :ok
  end

  test "Updating packages 2" do
    packs = [
      %{
        name: "fsm",
        link: "https://github.com/sasa1977/fsm",
        description: "Finite state machine as a functional data structure. ",
        heading: "Algorithms and Data structures",
        stars: 0,
        lastupdate: 0
      }
    ]

    assert FunboxQtElixir.AwesomeServer.update_packs(1, packs) == :ok
  end
end
