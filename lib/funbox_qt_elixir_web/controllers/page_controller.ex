defmodule FunboxQtElixirWeb.PageController do
  use FunboxQtElixirWeb, :controller

  # Короткий псевдоним доступа к серверу состояния awesome-list
  alias FunboxQtElixir.AwesomeServer, as: State

  def index(conn, params) do
    min_stars =
      try do
        %{"min_stars" => min_stars} = params
        String.to_integer(min_stars)
      rescue
        _e -> 0
      end

    %{categories: categories, all_packs: all_packs} =
      try do
        State.get_awesome_list(min_stars)
      rescue
        _e -> %{categories: [], all_packs: []}
      end

    render(conn, "index.html", categories: categories, all_packs: all_packs)
  end
end
