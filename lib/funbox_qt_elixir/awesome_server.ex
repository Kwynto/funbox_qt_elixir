defmodule FunboxQtElixir.AwesomeServer do
  @moduledoc """
  	Хранение состояния об awesome-list в DETS и предоставление информации о нем сайту.
  """
  use GenServer

  require Logger
  alias :dets, as: Storage, warn: false

  #######################
  # Client's functions
  #######################

  @doc """
  	Получение пакетов и категорий по количеству звезд
  """
  def getAwesomeList(min_stars) do
    [{:status, status}] = Storage.match_object(:state, {:status, :_})
    categories = Storage.match_object(:categories, {:_, :_, :_})

    all_packs =
      Storage.select(:all_packs, [
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

  # Обновить звезды и даты
  defp castUpdateStatusLinks() do
    GenServer.cast(__MODULE__, :update_status_links)
  end

  #######################
  # Server functions
  #######################

  @doc """
  	Start function for supervisor
  """
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  	Initialization function
  """
  def init(_init_state) do
    Logger.info("AwesomeServer started.")
    # стартовые состояния
    Storage.open_file(:state, type: :set)
    Storage.insert(:state, {:status, "inited"})
    Storage.open_file(:categories, type: :set)
    Storage.open_file(:all_packs, type: :set)
    # загрузка и парсинг awesome-list
    castUpdateStatusLinks()
    init_state = %{"status" => "inited"}
    {:ok, init_state}
  end

  @doc """
  	Парсинг списка и опрос GitHub на количество звезд и даты апдейта
  """
  def handle_cast(:update_status_links, state) do
    map_result = FunboxQtElixir.Awesome.runParse()
    %{"status" => status} = map_result

    state =
      if status == "loaded" do
        Logger.info("The update has begun ...")
        result_update = FunboxQtElixir.Awesome.questionGitHubData(map_result)
        Storage.delete_all_objects(:categories)
        Storage.delete_all_objects(:all_packs)
        Storage.open_file(:categories, type: :set)
        Storage.open_file(:all_packs, type: :set)

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

        Storage.insert(:categories, qry)

        qry =
          for pack <- all_packs do
            {pack.name, pack.link, pack.description, pack.heading, pack.stars, pack.lastupdate}
          end

        Storage.insert(:all_packs, qry)
        Storage.insert(:state, {:status, status})
        Logger.info("The update has finished!")
        # state = 
        %{"status" => status}
      else
        state
      end

    scheduleWork1()
    {:noreply, state}
  end

  @doc """
  	Закрытие сервера
  """
  def terminate(_reason, _state) do
    # Do Shutdown Stuff
    Storage.close(:state)
    Storage.close(:categories)
    Storage.close(:all_packs)
    :normal
  end

  @doc """
  	Ежедневное обновления всего листа и состояния пакетов
  """
  def handle_info(:timercast1, state) do
    Logger.info("Daily update.")
    castUpdateStatusLinks()
    {:noreply, state}
  end

  # Таймер на сутки
  defp scheduleWork1() do
    Process.send_after(self(), :timercast1, 86_400_000)

    # Process.send_after(self(), :timercast1, 300_000) # тестовое значение (5 минут)
  end
end
