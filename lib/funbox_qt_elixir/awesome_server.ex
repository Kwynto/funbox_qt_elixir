defmodule FunboxQtElixir.AwesomeServer do
  @moduledoc """
    Хранение состояния об awesome-list в DETS и предоставление информации о нем сайту.
  """
  use GenServer

  require Logger
  alias :dets, as: Storage

  #######################
  # Client's functions
  #######################

  @doc """
    Получение пакетов и категорий по количеству звезд
    (для контоллера)
  """
  @spec get_awesome_list(integer()) :: %{categories: list(), all_packs: list()}
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
          name: name,
          link: link,
          description: description,
          heading: heading,
          stars: stars,
          lastupdate: lastupdate
        }
      end

    # Сортируем пакеты по имени в алфавитном порядке
    all_packs = Enum.sort_by(all_packs, & &1.name, :asc)

    # Получаем список категорий из DETS
    categories = Storage.match_object(:categories, {:_, :_, :_})
    # Форматируем категории в удобный формат
    categories =
      for item <- categories do
        {title, link, description} = item
        %{title: title, link: link, description: description}
      end

    # Сортируем категории по названию в алфавитном порядке
    categories = Enum.sort_by(categories, & &1.title, :asc)

    # Делаем выборку только тех категорий, которые подходят к выбраным пакетам
    categories = FunboxQtElixir.AwesomeProbing.check_for_matches(categories, all_packs)

    # отдаем категории и пакеты в контроллер
    %{categories: categories, all_packs: all_packs}
  end

  @doc """
    Функция обновления данных о наборе пакетов и сохранение данных в DETS (запускается в паралельном процессе)
  """
  @spec update_packs(integer(), list()) :: :ok
  def update_packs(flow_num, packs) do
    Logger.info("Flow № #{flow_num} started.")

    # Получаем из конфигурации метод опроса GitHub true = GitHub API, false = Floki
    enquiry = Application.get_env(:funbox_qt_elixir, :enquiry_gha)

    result =
      unless enquiry do
        # последовательное обновление блока данных о пакетах через Floki
        for pack <- packs do
          FunboxQtElixir.AwesomeProbing.enquiry_github_data_via_floki(pack, flow_num)
        end
      else
        # последовательное обновление блока данных о пакетах через GitHub API
        for pack <- packs do
          FunboxQtElixir.AwesomeProbing.enquiry_github_data_via_api(pack, flow_num)
        end
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
  @spec start_link(any()) :: :ok
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
    Initialization function
  """
  @spec start_link(map()) :: {:ok, map()}
  def init(init_state) do
    Logger.info("AwesomeServer started.")

    # открываем дисковые таблицы или создаем новые для хранения данных
    Storage.open_file(:categories, type: :set)
    Storage.open_file(:all_packs, type: :set)

    # Запускаем загрузку и парсинг awesome-list
    GenServer.cast(__MODULE__, :update_awesome_list)

    {:ok, init_state}
  end

  @doc """
    Запрос на парсинга списка и на опрос GitHub на количество звезд и даты обновления
  """
  def handle_cast(:update_awesome_list, state) do
    # уставнавливаем таймер на сутки
    schedule_work1()
    # запрашиваем загрузку и парсинг
    map_result = FunboxQtElixir.AwesomeParse.run_parse()
    # разделяем результат на категории и список пакетов
    %{categories: categories, all_packs: all_packs} = map_result
    # сохраняем категории
    GenServer.cast(__MODULE__, {:save_categories, categories})
    # запрашиваем обновление данных обо всех пакетах
    GenServer.cast(__MODULE__, {:update_all_packs, all_packs})

    {:noreply, state}
  end

  @doc """
    Обновление данных обо всех пакетах
  """
  def handle_cast({:update_all_packs, packs}, state) do
    # Получаем количество потоков из конфигурации
    count_flow = Application.get_env(:funbox_qt_elixir, :count_flow)

    # разделение списка всех пакетов на списки для потоков
    div_packs = FunboxQtElixir.AwesomeProbing.div_list(packs, count_flow)

    # запуск паралельных процессов для обновления информации о пакетах
    # num - номер потока
    # item - список пакетов для потока
    for {num, item} <- div_packs do
      # Запуск update_packs/2 в отдельном процессе
      Task.start(__MODULE__, :update_packs, [num, item])
    end

    {:noreply, state}
  end

  @doc """
    Сохранение категорий в DETS
  """
  def handle_cast({:save_categories, categories}, state) do
    # Удаление старых категорий
    Storage.delete_all_objects(:categories)

    # Подготовка запроса для массового сохранения данных в DETS (список кортежей)
    qry =
      for category <- categories do
        # формируем кортеж
        {category.title, category.link, category.description}
      end

    # Обновление данных о категориях в хранилище
    Storage.insert(:categories, qry)
    {:noreply, state}
  end

  @doc """
    Сохранение данных о пакетах в DETS
  """
  def handle_cast({:save_packs, packs}, state) do
    # Подготовка списка пакетов (удаление дублей и остатков от непроверенных пакетов)
    packs =
      packs
      |> Enum.uniq()
      |> Enum.reject(fn x -> x == nil end)

    # Подготовка запроса для массового сохранения данных в DETS (список кортежей)
    qry =
      for pack <- packs do
        # формируем кортеж
        {pack.name, pack.link, pack.description, pack.heading, pack.stars, pack.lastupdate}
      end

    # Обновление (или запись новых) данных о пакетах в хранилище
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
    # Запрос на обновление списка пакетов
    GenServer.cast(__MODULE__, :update_awesome_list)
    {:noreply, state}
  end

  # Таймер на сутки
  defp schedule_work1() do
    Process.send_after(self(), :timercast1, 86_400_000)
  end
end
