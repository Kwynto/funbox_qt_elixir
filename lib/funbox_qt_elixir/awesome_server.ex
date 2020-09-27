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

  # Обновить звезды и даты всех пакетов
  defp castUpdateStatusLinks() do
    GenServer.cast(__MODULE__, :update_status_links)
  end

  # Обновить звезды и даты одного нового пакета
  # defp castUpdateStatusOneLink() do
  #   GenServer.cast(__MODULE__, :update_status_one_link)
  # end

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
    %{"status" => status, "categories" => categories, "all_packs" => all_packs} = map_result

    # Подготовка стейта, для асинхронной проверки количества звезд и даты обновления
    # tail_packs - "хвост" из непроверенных пакетов
    # acc_packs  - "аккумулятор" из проверенных пакетов
    state =
      if status == "loaded" do
        Logger.info("The update has begun ...")

        %{
          "status" => status,
          "new_categories" => categories,
          "tail_packs" => all_packs,
          "acc_packs" => []
        }
      else
        state
      end

    # state =
    #   if status == "loaded" do
    #     Logger.info("The update has begun ...")
    #     result_update = FunboxQtElixir.Awesome.questionGitHubData(map_result)
    #     Storage.delete_all_objects(:categories)
    #     Storage.delete_all_objects(:all_packs)
    #     Storage.open_file(:categories, type: :set)
    #     Storage.open_file(:all_packs, type: :set)

    #     %{
    #       "status" => status,
    #       "categories" => categories,
    #       "resources" => _resources,
    #       "all_packs" => all_packs
    #     } = result_update

    #     qry =
    #       for category <- categories do
    #         {category.title, category.link, category.description}
    #       end

    #     Storage.insert(:categories, qry)

    #     qry =
    #       for pack <- all_packs do
    #         {pack.name, pack.link, pack.description, pack.heading, pack.stars, pack.lastupdate}
    #       end

    #     Storage.insert(:all_packs, qry)
    #     Storage.insert(:state, {:status, status})
    #     Logger.info("The update has finished!")
    #     # state = 
    #     %{"status" => status}
    #   else
    #     state
    #   end

    scheduleWork1()
    scheduleWork2()
    {:noreply, state}
  end

  @doc """
  	Опрос GitHub о состоянии одного пакета на количество звезд и даты апдейта
  """
  def handle_cast(:update_status_one_link, state) do
    %{
      "status" => status,
      "new_categories" => categories,
      "tail_packs" => tail_packs,
      "acc_packs" => acc_packs
    } = state

    state =
      case {tail_packs == [], status == "loaded"} do
        {true, true} ->
          # "хвост" пакетов пустой и состояние сервера после загрузки, значит все пакеты проверенны, сохраняем
          Storage.delete_all_objects(:categories)
          Storage.delete_all_objects(:all_packs)
          Storage.open_file(:categories, type: :set)
          Storage.open_file(:all_packs, type: :set)

          qry =
            for category <- categories do
              {category.title, category.link, category.description}
            end

          Storage.insert(:categories, qry)

          acc_packs = Enum.uniq(acc_packs)
          acc_packs = Enum.reject(acc_packs, fn x -> x == nil end)

          qry =
            for pack <- acc_packs do
              {pack.name, pack.link, pack.description, pack.heading, pack.stars, pack.lastupdate}
            end

          Storage.insert(:all_packs, qry)

          status = "checked"
          Storage.insert(:state, {:status, status})
          Logger.info("The update has finished!")
          %{"status" => status, "new_categories" => [], "tail_packs" => [], "acc_packs" => []}

        {false, true} ->
          # есть непроверенные пакеты, проверяем
          [head | new_tail] = tail_packs
          result = FunboxQtElixir.Awesome.questionOneGitHubData(head)
          acc_packs = acc_packs ++ [result]

          %{
            "status" => status,
            "new_categories" => categories,
            "tail_packs" => new_tail,
            "acc_packs" => acc_packs
          }

        _ ->
          # {false, false} и возможно {true, false}
          # нет надобности проверять состояние пакетов, просто возвращаем состояние как оно есть
          state
      end

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

  @doc """
  	Вызов запроса на обработку новых пакетов, если они есть
  """
  def handle_info(:timercast2, state) do
    # castUpdateStatusOneLink()
    GenServer.cast(__MODULE__, :update_status_one_link)
    scheduleWork2()
    {:noreply, state}
  end

  # Таймер на сутки
  defp scheduleWork1() do
    Process.send_after(self(), :timercast1, 86_400_000)

    # тестовое значение (90 минут)
    # Process.send_after(self(), :timercast1, 5_400_000)
  end

  # Таймер 1/10 секунды
  defp scheduleWork2() do
    Process.send_after(self(), :timercast2, 100)
  end
end
