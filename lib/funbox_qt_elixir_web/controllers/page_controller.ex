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

    full_data =
      try do
        State.getAwesomeList(min_stars)
      rescue
        _e -> %{"status" => "inited", "categories" => [], "all_packs" => []}
      end

    %{"status" => status, "categories" => categories, "all_packs" => all_packs} = full_data

    conn =
      if status == "inited" or status == "loaded" do
        conn
        |> put_flash(
          :info,
          "Package data is being updated. Actual data will be available in 15-20 minutes."
        )
      else
        conn
      end

    render(conn, "index.html", categories: categories, all_packs: all_packs)
  end
end
