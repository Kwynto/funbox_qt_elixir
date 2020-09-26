defmodule FunboxQtElixir.AwesomeServer do
  @moduledoc """
  	Хранение состояния об awesome-list в ETS и предоставление информации о нем сайту.
  """
  use GenServer

  alias :ets, as: ETS, warn: false

  #######################
  # Client's functions
  #######################

  @doc """
  	Start function for supervisor
  """
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  	Получение пакетов и категорий по количеству звезд
  """
  def getAwesomeList(min_stars) do
    [{:status, status}] = ETS.match_object(:state, {:status, :_})
    categories = ETS.match_object(:categories, {:_, :_, :_})

    all_packs =
      ETS.select(:all_packs, [
        {{:"$1", :"$2", :"$3", :"$4", :"$5", :"$6"}, [{:>=, :"$5", {:const, min_stars}}],
         [{{:"$1", :"$2", :"$3", :"$4", :"$5", :"$6"}}]}
      ])

    categories =
      for item <- categories do
        {title, link, description} = item
        %{:title => title, :link => link, :description => description}
      end

    all_packs =
      for item <- all_packs do
        {name, link, description, heading, stars, lastupdate} = item

        %{
          :name => name,
          :link => link,
          :description => description,
          :heading => heading,
          :stars => stars,
          :lastupdate => lastupdate
        }
      end

    categories = Enum.sort_by(categories, & &1.title, :asc)
    all_packs = Enum.sort_by(all_packs, & &1.name, :asc)
    categories = FunboxQtElixir.Awesome.checkForMatches(categories, all_packs)
    %{"status" => status, "categories" => categories, "resources" => [], "all_packs" => all_packs}
  end

  # Загрузка, обработка и обновление состояния
  defp castUpdateAwesomeList() do
    GenServer.cast(__MODULE__, {:update_awesome_list, []})
  end

  # Обновить звезды и даты
  defp castUpdateStatusLinks() do
    GenServer.cast(__MODULE__, :update_status_links)
  end

  #######################
  # Server functions
  #######################

  @doc """
  	Initialization function
  """
  def init(_init_state) do
    IO.puts("AwesomeServer started.")
    # стартовые состояния
    ETS.new(:state, [:set, :protected, :named_table])
    ETS.insert(:state, {:status, "inited"})
    ETS.new(:categories, [:set, :protected, :named_table])
    ETS.new(:all_packs, [:set, :protected, :named_table])
    # загрузка и парсинг awesome-list
    castUpdateAwesomeList()
    init_state = %{"status" => "inited"}
    {:ok, init_state}
  end

  @doc """
  	Загрузка списка пакетов и парсинг во внутренний формат
  """
  def handle_cast({:update_awesome_list, _value}, _state) do
    map_result = FunboxQtElixir.Awesome.runParse()
    %{"status" => status, "categories" => categories, "all_packs" => all_packs} = map_result
    ETS.delete(:categories)
    ETS.delete(:all_packs)
    ETS.new(:categories, [:set, :protected, :named_table])
    ETS.new(:all_packs, [:set, :protected, :named_table])

    qry =
      for category <- categories do
        {category.title, category.link, category.description}
      end

    ETS.insert(:categories, qry)

    qry =
      for pack <- all_packs do
        {pack.name, pack.link, pack.description, pack.heading, pack.stars, pack.lastupdate}
      end

    ETS.insert(:all_packs, qry)
    ETS.insert(:state, {:status, status})
    IO.puts("Awesome-List loaded.")
    state = %{"status" => status}
    castUpdateStatusLinks()
    {:noreply, state}
  end

  @doc """
  	Парсинг звезд и даты апдейта
  """
  def handle_cast(:update_status_links, state) do
    map_result = FunboxQtElixir.Awesome.runParse()
    %{"status" => status} = map_result

    state =
      if status == "loaded" do
        IO.puts("The update has begun ...")
        result_update = FunboxQtElixir.Awesome.parseGitHubData(map_result)
        ETS.delete(:categories)
        ETS.delete(:all_packs)
        ETS.new(:categories, [:set, :protected, :named_table])
        ETS.new(:all_packs, [:set, :protected, :named_table])

        %{
          "status" => status,
          "categories" => categories,
          "resources" => _resources,
          "all_packs" => all_packs
        } = result_update

        qry =
          for category <- categories do
            {category.title, category.link, category.description}
          end

        ETS.insert(:categories, qry)

        qry =
          for pack <- all_packs do
            {pack.name, pack.link, pack.description, pack.heading, pack.stars, pack.lastupdate}
          end

        ETS.insert(:all_packs, qry)
        ETS.insert(:state, {:status, status})
        IO.puts("The update has finished!")
        # state = 
        %{"status" => status}
      else
        state
      end

    scheduleWork1()
    {:noreply, state}
  end

  @doc """
  	Ежедневное обновления всего листа и состояния пакетов
  """
  def handle_info(:timercast1, state) do
    IO.puts("Daily update.")
    castUpdateStatusLinks()
    {:noreply, state}
  end

  # Таймер на сутки
  defp scheduleWork1() do
    Process.send_after(self(), :timercast1, 86_400_000)

    # Process.send_after(self(), :timercast1, 300_000) # тестовое значение (5 минут)
  end
end
