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
    (для контоллера)
  """
  def get_awesome_list(min_stars) do
    # Получаем список пакетов из DETS, у которых stars >= min_stars
    all_packs =
      Storage.select(:all_packs, [
        {{:"$1", :"$2", :"$3", :"$4", :"$5", :"$6"}, [{:>=, :"$5", {:const, min_stars}}],
         [{{:"$1", :"$2", :"$3", :"$4", :"$5", :"$6"}}]}
      ])

    # Форматируем список пакетов в удобный формат
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

    # Сортируем пакеты в алфавитном порядке
    all_packs = Enum.sort_by(all_packs, & &1.name, :asc)

    # Получаем список категорий из DETS
    categories = Storage.match_object(:categories, {:_, :_, :_})
    # Форматируем категории в удобный формат
    categories =
      for item <- categories do
        {title, link, description} = item
        %{:title => title, :link => link, :description => description}
      end

    # Сортируем категории в алфавитном порядке
    categories = Enum.sort_by(categories, & &1.title, :asc)

    # Делаем выборку только тех категорий, которые подходят к выбраным пакетам
    categories = FunboxQtElixir.AwesomeProbing.check_for_matches(categories, all_packs)

    # отдаем категории и пакеты в контроллер
    %{"categories" => categories, "all_packs" => all_packs}
  end

  # Функция обслуживания обновления данных в потоке и сохранение данных в DETS
  defp update_packs(packs, flow_num) do
    Logger.info("Flow № #{flow_num} started.")

    # синхронное последовательное обновление данных о пакетах в отдельном потоке
    result =
      for pack <- packs do
        FunboxQtElixir.AwesomeProbing.enquiry_github_data(pack, flow_num)
      end

    GenServer.cast(__MODULE__, {:save_packs, result})
    Logger.info("Flow № #{flow_num} ended and saved.")
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
  def init(init_state) do
    Logger.info("AwesomeServer started.")

    # стартовые состояния
    Storage.open_file(:categories, type: :set)
    Storage.open_file(:all_packs, type: :set)

    # загрузка и парсинг awesome-list
    GenServer.cast(__MODULE__, :update_awesome_list)

    {:ok, init_state}
  end

  @doc """
    Парсинг списка и опрос GitHub на количество звезд и даты апдейта
  """
  def handle_cast(:update_awesome_list, state) do
    schedule_work1()
    map_result = FunboxQtElixir.AwesomeParse.run_parse()
    %{"categories" => categories, "all_packs" => all_packs} = map_result

    GenServer.cast(__MODULE__, {:save_categories, categories})

    GenServer.cast(__MODULE__, {:update_all_packs, all_packs})

    {:noreply, state}
  end

  def handle_cast({:update_all_packs, packs}, state) do
    # Получаем количество потоков из конфигурации
    count_flow = :funbox_qt_elixir |> Application.get_env(:count_flow)

    # разделение списка всех пакетов на списки для потоков
    div_packs = FunboxQtElixir.AwesomeProbing.div_list(packs, count_flow)

    # запуск асинхронного потокового обновления информации о пакетах
    for {num, item} <- div_packs do
      # Запуск update_packs/2 в отдельном процессе
      Task.start(__MODULE__, :update_packs, [item, num])
    end

    {:noreply, state}
  end

  def handle_cast({:save_categories, categories}, state) do
    # Удаление старых категорий
    Storage.delete_all_objects(:categories)

    # Подготовка запроса для массового сохранения данных в DETS
    qry =
      for category <- categories do
        {category.title, category.link, category.description}
      end

    # Обновление данных о категориях в хранилище
    Storage.insert(:categories, qry)
    {:noreply, state}
  end

  def handle_cast({:save_packs, packs}, state) do
    # Подготовка списка пакетов (удаление дублей и остатков от непроверенных пакетов)
    packs =
      packs
      |> Enum.uniq()
      |> Enum.reject(fn x -> x == nil end)

    # Подготовка запроса для массового сохранения данных в DETS
    qry =
      for pack <- packs do
        {pack.name, pack.link, pack.description, pack.heading, pack.stars, pack.lastupdate}
      end

    # Обновление данных о пакетах в хранилище
    Storage.insert(:all_packs, qry)

    {:noreply, state}
  end

  @doc """
    Закрытие сервера
  """
  def terminate(_reason, _state) do
    Storage.close(:categories)
    Storage.close(:all_packs)
    :normal
  end

  @doc """
    Ежедневное обновления всего листа и состояния пакетов
  """
  def handle_info(:timercast1, state) do
    Logger.info("Daily update.")
    GenServer.cast(__MODULE__, :update_awesome_list)
    {:noreply, state}
  end

  # Таймер на сутки
  defp schedule_work1() do
    Process.send_after(self(), :timercast1, 86_400_000)

    # тестовое значение (30 минут)
    # Process.send_after(self(), :timercast1, 1_800_000)
  end
end
