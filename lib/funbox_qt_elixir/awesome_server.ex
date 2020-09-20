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
	def get_awesome_list(min_stars) do
		[{:status, status}] = ETS.match_object(:state, {:status, :"_"})
		categories = ETS.match_object(:categories, {:"_", :"_", :"_"})
		allpacks = ETS.select(:allpacks, [{{:"$1", :"$2", :"$3", :"$4", :"$5", :"$6"}, [{:>=, :"$5", {:const, min_stars}}], [{{:"$1", :"$2", :"$3", :"$4", :"$5", :"$6"}}]}])
		categories = for item <- categories do
			{title, link, description} = item
			%{:title => title, :link => link, :description => description}
		end
		allpacks = for item <- allpacks do
			{name, link, description, heading, stars, lastupdate} = item
			%{:name => name, :link => link, :description => description, :heading => heading, :stars => stars, :lastupdate => lastupdate}
		end
		categories = Enum.sort_by(categories, &(&1.title), :asc)
		allpacks = Enum.sort_by(allpacks, &(&1.name), :asc)
		categories = FunboxQtElixir.Awesome.check_for_matches(categories, allpacks)
		%{"status" => status, "categories" => categories, "resources" => [], "allpacks" => allpacks}
	end

	
	# Загрузка, обработка и обновление состояния
	defp cast_update_awesome_list() do
		GenServer.cast(__MODULE__, {:update_awesome_list, []})
	end

	# Обновить звезды и даты
	defp cast_update_status_links() do
		GenServer.cast(__MODULE__, :update_status_links)
	end

	#######################
	# Server functions
	#######################

	@doc """
		Initialization function
	"""
	def init(_init_state) do
		IO.puts "AwesomeServer started."
		# стартовые состояния
		ETS.new(:state, [:set, :protected, :named_table])
		ETS.insert(:state, {:status, "inited"})
		ETS.new(:categories, [:set, :protected, :named_table])
		ETS.new(:allpacks, [:set, :protected, :named_table])
		# загрузка и парсинг awesome-list
		cast_update_awesome_list()
		init_state = %{"status" => "inited"}
		{:ok, init_state}
	end

	@doc """
		Загрузка списка пакетов и парсинг во внутренний формат
	"""
	def handle_cast({:update_awesome_list, _value}, _state) do
		mapResult = FunboxQtElixir.Awesome.runParse()
		%{"status" => status, "categories" => categories, "allpacks" => allpacks} = mapResult
		ETS.delete(:categories)
		ETS.delete(:allpacks)
		ETS.new(:categories, [:set, :protected, :named_table])
		ETS.new(:allpacks, [:set, :protected, :named_table])
		qry = for category <- categories do
			{category.title, category.link, category.description}
		end
		ETS.insert(:categories, qry)
		qry = for pack <- allpacks do
			{pack.name, pack.link, pack.description, pack.heading, pack.stars, pack.lastupdate}
		end
		ETS.insert(:allpacks, qry)
		ETS.insert(:state, {:status, status})
		IO.puts "Awesome-List loaded."
		state = %{"status" => status}
		cast_update_status_links()
		{:noreply, state}
	end # update_awesome_list

	@doc """
		Парсинг звезд и даты апдейта
	"""
	def handle_cast(:update_status_links, state) do
		mapResult = FunboxQtElixir.Awesome.runParse()
		%{"status" => status} = mapResult
		state = if status == "loaded" do
			IO.puts "The update has begun ..."
			resultUpdate = FunboxQtElixir.Awesome.parse_GitHub_data(mapResult)
			ETS.delete(:categories)
			ETS.delete(:allpacks)
			ETS.new(:categories, [:set, :protected, :named_table])
			ETS.new(:allpacks, [:set, :protected, :named_table])
			%{"status" => status, "categories" => categories, "resources" => _resources, "allpacks" => allpacks} = resultUpdate
			qry = for category <- categories do
				{category.title, category.link, category.description}
			end
			ETS.insert(:categories, qry)
			qry = for pack <- allpacks do
				{pack.name, pack.link, pack.description, pack.heading, pack.stars, pack.lastupdate}
			end
			ETS.insert(:allpacks, qry)
			ETS.insert(:state, {:status, status})
			IO.puts "The update has finished!"
			# state = 
			%{"status" => status}
		else
			state
		end
		schedule_work1()
		{:noreply, state}
	end # update_awesome_list

	@doc """
		Ежедневное обновления всего листа и состояния пакетов
	"""
	def handle_info(:timercast1, state) do
		IO.puts "Daily update."
		cast_update_status_links()
		{:noreply, state}
	end

	# Таймер на сутки
	defp schedule_work1() do
		Process.send_after(self(), :timercast1, 86_400_000)
		# Process.send_after(self(), :timercast1, 300_000) # тестовое значение (5 минут)
	end

end