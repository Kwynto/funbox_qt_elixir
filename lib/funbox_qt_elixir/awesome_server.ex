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

  # def updateOnePack(pack) do
  #   result = FunboxQtElixir.Awesome.questionOneGitHubData(pack)
  #   GenServer.cast(__MODULE__, {:save_pack_in_state, result})
  # end

  def updatePacks(packs) do
    result =
      for pack <- packs do
        FunboxQtElixir.Awesome.questionOneGitHubData(pack)
      end

    GenServer.cast(__MODULE__, {:save_packs, result})
    # divList(packs, 10)
  end

  # Вход
  def divList(packs, count) do
    # формируем начальное состояние аккумуляторa
    acc = for item <- 1..count, into: %{}, do: {item, []}

    # начинаем разделение данных для паралельных потоков
    divList(packs, count, acc, 1)
  end

  # Выход
  def divList([], _count, acc, _next) do
    IO.puts("---------------------------")
    IO.inspect(acc)
    IO.puts("---------------------------")
    acc
  end

  # Переборка
  def divList(packs, count, acc, next) do
    # берем очередныой пакет
    [head | tail] = packs
    # получаем аккумулятор очередного потока
    %{^next => work_arr} = acc
    # добавляем пакет в аккумулятор потока
    work_arr = [head | work_arr]
    # обновляем полный аккумулятор
    acc = %{acc | next => work_arr}

    if next == count do
      divList(tail, count, acc, 1)
    else
      divList(tail, count, acc, next + 1)
    end
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
    GenServer.cast(__MODULE__, :update_status_links)
    init_state = %{"status" => "inited"}
    {:ok, init_state}
  end

  @doc """
  	Парсинг списка и опрос GitHub на количество звезд и даты апдейта
  """
  def handle_cast(:update_status_links, _state) do
    scheduleWork1()
    map_result = FunboxQtElixir.Awesome.runParse()
    %{"status" => status, "categories" => categories, "all_packs" => all_packs} = map_result

    GenServer.cast(__MODULE__, {:save_categories, categories})

    GenServer.cast(__MODULE__, {:update_all_packs, all_packs})

    state = %{"status" => status}
    {:noreply, state}
  end

  def handle_cast({:update_all_packs, packs}, state) do
    div_packs = divList(packs, 10)

    for {_num, item} <- div_packs do
      Task.start(__MODULE__, :updatePacks, [item])
    end

    {:noreply, state}
  end

  def handle_cast({:save_categories, categories}, state) do
    Storage.delete_all_objects(:categories)

    qry =
      for category <- categories do
        {category.title, category.link, category.description}
      end

    Storage.insert(:categories, qry)
    {:noreply, state}
  end

  def handle_cast({:save_packs, packs}, state) do
    # Storage.delete_all_objects(:all_packs)

    packs =
      packs
      |> Enum.uniq()
      |> Enum.reject(fn x -> x == nil end)

    qry =
      for pack <- packs do
        {pack.name, pack.link, pack.description, pack.heading, pack.stars, pack.lastupdate}
      end

    Storage.insert(:all_packs, qry)

    {:noreply, state}
  end

  # def handle_cast({:save_pack, pack}, state) do
  #   Storage.insert(:all_packs, pack)
  #   {:noreply, state}
  # end

  # def handle_cast({:save_pack_in_state, pack}, %{"acc_packs" => acc_packs} = state) do
  #   acc_packs = acc_packs ++ [pack]
  #   state = %{state | "acc_packs" => acc_packs}
  #   {:noreply, state}
  # end

  # def handle_cast({:question_status_one_link, value}, %{"acc_packs" => acc_packs} = state) do
  #   result = FunboxQtElixir.Awesome.questionOneGitHubData(value)
  #   acc_packs = acc_packs ++ [result]
  #   state = %{state | "acc_packs" => acc_packs}
  #   {:noreply, state}
  # end

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
    GenServer.cast(__MODULE__, :update_status_links)
    {:noreply, state}
  end

  # Таймер на сутки
  defp scheduleWork1() do
    Process.send_after(self(), :timercast1, 86_400_000)

    # тестовое значение (90 минут)
    # Process.send_after(self(), :timercast1, 5_400_000)
  end
end
