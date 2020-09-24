defmodule FunboxQtElixir.AwesomeServerTest do
  use FunboxQtElixir.AwesomeCase

  test "Starting AwesomeServer" do
    {okvar, _pid} = FunboxQtElixir.AwesomeServer.start_link({:start})
    assert okvar == :ok
  end

  test "Starting AwesomeServer from init/1" do
    {okvar, _pid} = FunboxQtElixir.AwesomeServer.init({:start})
    assert okvar == :ok
  end

  test "Geting all state" do
    FunboxQtElixir.AwesomeServer.start_link({:start})
    min_stars = 0
    result = FunboxQtElixir.AwesomeServer.get_awesome_list(min_stars)
    %{"status" => status, "categories" => categories, "allpacks" => allPacks} = result

    assert is_bitstring(status) == true
    assert is_list(categories) == true
    assert is_list(allPacks) == true
  end

  test "Geting state with over 10 stars" do
    FunboxQtElixir.AwesomeServer.start_link({:start})
    min_stars = 10
    result = FunboxQtElixir.AwesomeServer.get_awesome_list(min_stars)
    %{"status" => status, "categories" => categories, "allpacks" => allPacks} = result

    assert is_bitstring(status) == true
    assert is_list(categories) == true
    assert is_list(allPacks) == true
  end

  test "Geting state with over 50 stars" do
    FunboxQtElixir.AwesomeServer.start_link({:start})
    min_stars = 50
    result = FunboxQtElixir.AwesomeServer.get_awesome_list(min_stars)
    %{"status" => status, "categories" => categories, "allpacks" => allPacks} = result

    assert is_bitstring(status) == true
    assert is_list(categories) == true
    assert is_list(allPacks) == true
  end

  test "Geting state with over 100 stars" do
    FunboxQtElixir.AwesomeServer.start_link({:start})
    min_stars = 100
    result = FunboxQtElixir.AwesomeServer.get_awesome_list(min_stars)
    %{"status" => status, "categories" => categories, "allpacks" => allPacks} = result

    assert is_bitstring(status) == true
    assert is_list(categories) == true
    assert is_list(allPacks) == true
  end

  test "Geting state with over 500 stars" do
    FunboxQtElixir.AwesomeServer.start_link({:start})
    min_stars = 500
    result = FunboxQtElixir.AwesomeServer.get_awesome_list(min_stars)
    %{"status" => status, "categories" => categories, "allpacks" => allPacks} = result

    assert is_bitstring(status) == true
    assert is_list(categories) == true
    assert is_list(allPacks) == true
  end

  test "Geting state with over 1000 stars" do
    FunboxQtElixir.AwesomeServer.start_link({:start})
    min_stars = 1000
    result = FunboxQtElixir.AwesomeServer.get_awesome_list(min_stars)
    %{"status" => status, "categories" => categories, "allpacks" => allPacks} = result

    assert is_bitstring(status) == true
    assert is_list(categories) == true
    assert is_list(allPacks) == true
  end
end
