defmodule FunboxQtElixir.Awesome do
  @moduledoc """
  	Модуль для обработки h4cc/awesome-elixir.
  	Загрузка, парсинг во внтренний формат, опрос GitHub на актуальную информацию 
  	и формирование стейта для использования в GenServer.
  """

  @doc """
  	Точка входа.
  	Загрузка awesom-list в формате MD, парсинг в удобный внутренний формат 
  	и опрашивание GitHub на актуальную информацию.
  """
  def runParse() do
    # скачиваем список пакетов
    %HTTPoison.Response{body: lines} =
      HTTPoison.get!("https://raw.githubusercontent.com/h4cc/awesome-elixir/master/README.md")

    # Парсим загруженный MD-файл
    parseAwesomeList(lines)
  end

  @doc """
  	Парсим весь входящий awesom-list в формате MD.
  	Входящие данный: скачанные или загруженные из файла данные.
  	Исходящеи данный: ассоциативный массив %{"categories" => categories, "resources" => resources, "allpacks" => allPacks}
  		каждое поле является списком,
  		categories - список строк с названиями категорий,
  		resources - список строк с названиями ресурсов,
  		allpacks - список пакетов из awesom-list = список ассоциативных массивов (maps),
  			где каждая мапа описывает конкретный пакет в формате %{"name" => name, "link" => link, "description" => description, "heading" => heading, "stars" => 0, lastupdate => 0}
  				где: 
  					name - (string) имя пакета,
  					link - (string) ссылка,
  					description - (string) описание пакета, 
  					heading - (string) к какому заголовку относится (соответствует названию в categories или в resources),
  					stars - (integer) количество звезд на GitHub (default = 0) (ещё нужно парсить GitHub на звезды),
  					lastupdate - (integer) количество дней с последнего обновленя (default = 0) (ещё нужно парсить GitHub).
  """
  def parseAwesomeList(lines) do
    # Делим и парсим на блоки
    {blocks, _links, _options} = EarmarkParser.Parser.parse(String.split(lines, ~r{\r\n?|\n}))
    # Убеждаемся что есть заголовок и отбрасываем его
    [%EarmarkParser.Block.Heading{} | blocks] = blocks

    # Отбрасываем лишние заголовочные и описательные блоки
    [_intro | blocks] = blocks
    [_like | blocks] = blocks
    [_other | blocks] = blocks

    # Получаем список с содержимым (заголовки) и остаток содержимого для оснвогого тела
    [%EarmarkParser.Block.List{blocks: tableOfContent} | blocksList] = blocks
    # Парсим заголовки на категории
    [
      %EarmarkParser.Block.ListItem{blocks: [%EarmarkParser.Block.Text{} | categories]}
      | tableOfContent
    ] = tableOfContent

    [%EarmarkParser.Block.List{blocks: categories}] = categories

    categories =
      for %EarmarkParser.Block.ListItem{blocks: [%EarmarkParser.Block.Text{line: [name]}]} <-
            categories do
        {title, link} = parse_markdown_link(name)
        link = String.replace(link, "#", "")
        %{:title => title, :link => link, :description => ""}
      end

    # Парсим остаток загловков для блока ресурсов
    [
      %EarmarkParser.Block.ListItem{blocks: [%EarmarkParser.Block.Text{} | resources]}
      | _tableOfContent
    ] = tableOfContent

    [%EarmarkParser.Block.List{blocks: resources}] = resources

    resources =
      for %EarmarkParser.Block.ListItem{blocks: [%EarmarkParser.Block.Text{line: [name]}]} <-
            resources do
        {title, link} = parse_markdown_link(name)
        link = String.replace(link, "#", "")
        %{:title => title, :link => link, :description => ""}
      end

    # Парсим основной контент как список кортежей с категориями
    # и дополнительно вытягиваем описания категорий
    {:combopack, allPacks, categories} = iterate_content(blocksList, [], categories)

    allPacks =
      allPacks
      |> unblocking_content([])
      |> Enum.reverse()

    # Формируем полный стейт
    %{
      "status" => "loaded",
      "categories" => categories,
      "resources" => resources,
      "allpacks" => allPacks
    }
  end

  # regex для описания пакета
  @description_regex ~r/^(.+)\[([^]]+)\]\(([^)]+)\)(.+)$/

  @doc """
  	Парсим строку описания на наличие дополнительной ссылки на технологию (через регулярное выражение)
  	Используется в шаблоне.
  """
  def parse_description(description) do
    case Regex.run(@description_regex, description) do
      # доп. ссылки нет -> вставляем описание как было
      nil -> description
      [^description, beginStr, name, link, endStr] -> {:description, beginStr, link, name, endStr}
    end
  end

  @doc """
  	Проверяет содержится ли внутри описания ссылка (true or false)
  	Используется в шаблоне.
  """
  def parse_description?(description) do
    case Regex.run(@description_regex, description) do
      nil -> false
      [^description, _beginStr, _name, _link, _endStr] -> true
    end
  end

  # Разделение отдельных хэш-тегов заголовка на имя и ссылку
  defp parse_markdown_link(string) do
    [^string, title, link] = Regex.run(~r/\[(.+)\]\((.+)\)/, string)
    {title, link}
  end

  # Удаляем внтренние массивы, отавшиеся от старой структуры из MD
  # Клауза выхода, БЕЗ реверса
  defp unblocking_content([], acc) do
    acc
  end

  # Основной блок переборки списка
  defp unblocking_content([head | tail], acc) do
    # Перебераем пакеты в категории (обычная рекурсия = нарастание стека)
    acc = unblocking_content(head, acc)

    # Переходим к переборке остального тела (хвостовая рекурсия)
    unblocking_content(tail, acc)
  end

  # Добавление кортежа с описанием пакета в результирующий список
  defp unblocking_content(map, acc) do
    [map | acc]
  end

  # Переборка основного тела со списком пакетов
  # Клауза для выхода из функции и реверс результата
  defp iterate_content([], acc, categories) do
    {:combopack, Enum.reverse(acc), categories}
  end

  # Поиск заголовка 2-го уровня
  defp iterate_content(
         [
           %EarmarkParser.Block.Heading{content: heading, level: 2},
           %EarmarkParser.Block.Para{lines: [lines]},
           %EarmarkParser.Block.List{blocks: blocks, type: :ul} | tail
         ],
         acc,
         categories
       ) do
    # получаем описание категорий в процессе переборки основных болков
    cats =
      for category <- categories do
        if heading == category.title, do: %{category | description: lines}, else: category
      end

    acc = [check_list(blocks, heading) | acc]
    iterate_content(tail, acc, cats)
  end

  # Поиск заголовка 1-го уровня
  defp iterate_content(
         [
           %EarmarkParser.Block.Heading{content: _heading, level: 1},
           %EarmarkParser.Block.Para{lines: _lines} | tail
         ],
         acc,
         categories
       ) do
    iterate_content(tail, acc, categories)
  end

  # Ошибка заголовка, когда нет совпадений
  defp iterate_content([_head | tail], acc, categories) do
    iterate_content(tail, acc, categories)
  end

  # Переборка всех данных описания конкретного пакета
  defp check_list(list, heading) do
    for listItem <- list do
      line =
        try do
          %EarmarkParser.Block.ListItem{
            blocks: [%EarmarkParser.Block.Text{line: [line]}],
            type: :ul
          } = listItem

          line
        rescue
          _e ->
            %EarmarkParser.Block.ListItem{
              blocks: [%EarmarkParser.Block.Para{lines: [line]}],
              type: :ul
            } = listItem

            line
        end

      line =
        case String.starts_with?(line, "~~") and String.ends_with?(line, "~~") do
          true ->
            line |> String.trim_trailing() |> String.trim(?~)

          false ->
            String.trim_trailing(line)
        end

      [name, link, description | _rest] = parse_line(line)

      %{
        :name => name,
        :link => link,
        :description => description,
        :heading => heading,
        :stars => 0,
        :lastupdate => 0
      }
    end
  end

  # regex для пакета
  @line_regex ~r/^\[([^]]+)\]\(([^)]+)\) - (.+)([\.\!]+)$/

  # Парсим строку пакета на: имя, ссылку и описание (через регулярное выражение)
  defp parse_line(line) do
    case Regex.run(@line_regex, line) do
      nil -> raise("Line does not match format: '#{line}' Is there a dot at the end?")
      [^line, name, link, description, dot] -> [name, link, " " <> description <> dot]
    end
  end

  @doc """
  	Парсинг пакетов на GitHub
  """
  def parse_GitHub_data(data) do
    %{
      "status" => status,
      "categories" => categories,
      "resources" => resources,
      "allpacks" => allPacks
    } = data

    resultParse = parseStatus(allPacks, {:resState, status, []})
    {:resState, resStatus, resPacks} = resultParse
    # Формируем полный стейт
    %{
      "status" => resStatus,
      "categories" => categories,
      "resources" => resources,
      "allpacks" => resPacks
    }
  end

  # Клауз закрытия для парсинга GitHub
  defp parseStatus([], acc) do
    {:resState, _resStatus, resPacks} = acc
    {:resState, "checked", resPacks}
  end

  # Основной рабочий клауз для парсинга GitHub
  defp parseStatus([head | tail], acc) do
    try do
      %{link: oneLink, stars: oneStars, lastupdate: oneLU} = head

      if oneStars == 0 and oneLU == 0 do
        oneLinkRepos =
          String.replace(
            oneLink,
            "https://github.com/",
            "https://fb-qt-elixir:Fmk9h0mda@api.github.com/repos/",
            global: false
          )

        %HTTPoison.Response{body: lines} = HTTPoison.get!(oneLinkRepos)
        {status, responseGHA} = Jason.decode(lines)

        acc2 =
          if status == :ok do
            {respUpdated, respStars, stat_active} =
              case responseGHA do
                %{"commits_url" => respCommitsUrl, "stargazers_count" => respStars} ->
                  {getCommitUpdated(respCommitsUrl), respStars, 1}

                %{"documentation_url" => _doc_url_GH, "message" => _mes_GH, "url" => url_GH} ->
                  oneLinkRepos =
                    String.replace(
                      url_GH,
                      "https://api.github.com/",
                      "https://fb-qt-elixir:Fmk9h0mda@api.github.com/",
                      global: false
                    )

                  %HTTPoison.Response{body: lines} = HTTPoison.get!(oneLinkRepos)
                  {_status, responseGHA} = Jason.decode(lines)

                  %{"commits_url" => respCommitsUrl, "stargazers_count" => respStars} =
                    responseGHA

                  {getCommitUpdated(respCommitsUrl), respStars, 1}

                %{"documentation_url" => _doc_url_GH, "message" => _mes_GH} ->
                  {0, 0, 0}

                _ ->
                  {0, 0, 0}
              end

            acc2 =
              if stat_active != 0 do
                {:ok, respUpdatedDT, 0} = DateTime.from_iso8601(respUpdated)

                daysPassed =
                  div(
                    DateTime.to_unix(DateTime.now!("Etc/UTC")) - DateTime.to_unix(respUpdatedDT),
                    86400
                  )

                IO.write("Package information updated: ")
                IO.inspect(oneLink)
                oneRes = %{head | stars: respStars, lastupdate: daysPassed}
                {:resState, resStatus, resPacks} = acc
                resPacks = resPacks ++ [oneRes]
                {:resState, resStatus, resPacks}
              else
                # Непроверяемый пакет идем дальше
                acc
              end

            acc2
          else
            # Непроверяемый пакет идем дальше
            acc
          end

        # Отработало подключение идем дальше по пакетам
        parseStatus(tail, acc2)
      else
        {:resState, resStatus, resPacks} = acc
        resPacks = resPacks ++ [head]
        acc2 = {:resState, resStatus, resPacks}
        parseStatus(tail, acc2)
      end
    rescue
      _e -> parseStatus(tail, acc)
    end
  end

  # Получить дату последнего обновления последнего коммита
  defp getCommitUpdated(url) do
    try do
      oneLinkRepos =
        String.replace(url, "https://", "https://fb-qt-elixir:Fmk9h0mda@", global: false)

      oneLinkFirstCommit = String.replace(oneLinkRepos, "{/sha}", "")
      %HTTPoison.Response{body: lines} = HTTPoison.get!(oneLinkFirstCommit)
      {status, responseGHA} = Jason.decode(lines)

      if status == :ok do
        [headResponseGHA | _tail] = responseGHA
        %{"commit" => %{"committer" => %{"date" => respUpdated}}} = headResponseGHA
        respUpdated
      else
        DateTime.to_string(DateTime.now!("Etc/UTC"))
      end
    rescue
      _e -> DateTime.to_string(DateTime.now!("Etc/UTC"))
    end
  end

  @doc """
  	Проверка совпадений спаска категорий со списком найденных пакетов
  	и возврат актуального списка categories
  """
  def check_for_matches(categories, allpacks) do
    listHeading =
      for onePack <- allpacks do
        %{:heading => heading} = onePack
        heading
      end

    listHeading = Enum.uniq(listHeading)

    categories =
      for category <- categories do
        Enum.find_value(listHeading, fn x -> if x == category.title, do: category end)
      end

    Enum.reject(categories, fn x -> x == nil end)
  end
end
