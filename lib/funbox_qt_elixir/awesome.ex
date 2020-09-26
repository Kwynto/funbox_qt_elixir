defmodule FunboxQtElixir.Awesome do
  @moduledoc """
  	Модуль для обработки h4cc/awesome-elixir.
  	Загрузка, парсинг во внтренний формат, опрос GitHub на актуальную информацию 
  	и формирование стейта для использования в GenServer.
  """

  require Logger

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
  	Исходящеи данный: ассоциативный массив %{"categories" => categories, "resources" => resources, "all_packs" => all_packs}
  		каждое поле является списком,
  		categories - список строк с названиями категорий,
  		resources - список строк с названиями ресурсов,
  		all_packs - список пакетов из awesom-list = список ассоциативных массивов (maps),
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
    [%EarmarkParser.Block.List{blocks: table_of_content} | blocks_list] = blocks
    # Парсим заголовки на категории
    [
      %EarmarkParser.Block.ListItem{blocks: [%EarmarkParser.Block.Text{} | categories]}
      | table_of_content
    ] = table_of_content

    [%EarmarkParser.Block.List{blocks: categories}] = categories

    categories =
      for %EarmarkParser.Block.ListItem{blocks: [%EarmarkParser.Block.Text{line: [name]}]} <-
            categories do
        {title, link} = parseMarkdownLink(name)
        link = String.replace(link, "#", "")
        %{:title => title, :link => link, :description => ""}
      end

    # Парсим остаток загловков для блока ресурсов
    [
      %EarmarkParser.Block.ListItem{blocks: [%EarmarkParser.Block.Text{} | resources]}
      | _table_of_content
    ] = table_of_content

    [%EarmarkParser.Block.List{blocks: resources}] = resources

    resources =
      for %EarmarkParser.Block.ListItem{blocks: [%EarmarkParser.Block.Text{line: [name]}]} <-
            resources do
        {title, link} = parseMarkdownLink(name)
        link = String.replace(link, "#", "")
        %{:title => title, :link => link, :description => ""}
      end

    # Парсим основной контент как список кортежей с категориями
    # и дополнительно вытягиваем описания категорий
    {:combopack, all_packs, categories} = iterateContent(blocks_list, [], categories)

    all_packs =
      all_packs
      |> unblockingContent([])
      |> Enum.reverse()

    # Формируем полный стейт
    %{
      "status" => "loaded",
      "categories" => categories,
      "resources" => resources,
      "all_packs" => all_packs
    }
  end

  # regex для описания пакета
  @description_regex ~r/^(.+)\[([^]]+)\]\(([^)]+)\)(.+)$/

  @doc """
  	Парсим строку описания на наличие дополнительной ссылки на технологию (через регулярное выражение)
  	Используется в шаблоне.
  """
  def divisionDescription(description) do
    case Regex.run(@description_regex, description) do
      # доп. ссылки нет -> вставляем описание как было
      nil ->
        description

      [^description, begin_str, name, link, end_str] ->
        {:description, begin_str, link, name, end_str}
    end
  end

  @doc """
  	Проверяет содержится ли внутри описания ссылка (true or false)
  	Используется в шаблоне.
  """
  def divisionDescription?(description) do
    case Regex.run(@description_regex, description) do
      nil -> false
      [^description, _begin_str, _name, _link, _end_str] -> true
    end
  end

  # Разделение отдельных хэш-тегов заголовка на имя и ссылку
  defp parseMarkdownLink(string) do
    [^string, title, link] = Regex.run(~r/\[(.+)\]\((.+)\)/, string)
    {title, link}
  end

  # Удаляем внтренние массивы, отавшиеся от старой структуры из MD
  # Клауза выхода, БЕЗ реверса
  defp unblockingContent([], acc) do
    acc
  end

  # Основной блок переборки списка
  defp unblockingContent([head | tail], acc) do
    # Перебераем пакеты в категории (обычная рекурсия = нарастание стека)
    acc = unblockingContent(head, acc)

    # Переходим к переборке остального тела (хвостовая рекурсия)
    unblockingContent(tail, acc)
  end

  # Добавление кортежа с описанием пакета в результирующий список
  defp unblockingContent(map, acc) do
    [map | acc]
  end

  # Переборка основного тела со списком пакетов
  # Клауза для выхода из функции и реверс результата
  defp iterateContent([], acc, categories) do
    {:combopack, Enum.reverse(acc), categories}
  end

  # Поиск заголовка 2-го уровня
  defp iterateContent(
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

    acc = [checkList(blocks, heading) | acc]
    iterateContent(tail, acc, cats)
  end

  # Поиск заголовка 1-го уровня
  defp iterateContent(
         [
           %EarmarkParser.Block.Heading{content: _heading, level: 1},
           %EarmarkParser.Block.Para{lines: _lines} | tail
         ],
         acc,
         categories
       ) do
    iterateContent(tail, acc, categories)
  end

  # Ошибка заголовка, когда нет совпадений
  defp iterateContent([_head | tail], acc, categories) do
    iterateContent(tail, acc, categories)
  end

  # Переборка всех данных описания конкретного пакета
  defp checkList(list, heading) do
    for list_item <- list do
      line =
        try do
          %EarmarkParser.Block.ListItem{
            blocks: [%EarmarkParser.Block.Text{line: [line]}],
            type: :ul
          } = list_item

          line
        rescue
          _e ->
            %EarmarkParser.Block.ListItem{
              blocks: [%EarmarkParser.Block.Para{lines: [line]}],
              type: :ul
            } = list_item

            line
        end

      line =
        case String.starts_with?(line, "~~") and String.ends_with?(line, "~~") do
          true ->
            line |> String.trim_trailing() |> String.trim(?~)

          false ->
            String.trim_trailing(line)
        end

      [name, link, description | _rest] = parseLine(line)

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
  defp parseLine(line) do
    case Regex.run(@line_regex, line) do
      nil -> raise("Line does not match format: '#{line}' Is there a dot at the end?")
      [^line, name, link, description, dot] -> [name, link, " " <> description <> dot]
    end
  end

  @doc """
  	Опрос GitHub API для получения количества звезд у пакетов и даты последнего обновления
  """
  def questionGitHubData(data) do
    %{
      "status" => status,
      "categories" => categories,
      "resources" => resources,
      "all_packs" => all_packs
    } = data

    result_question = questionStatus(all_packs, {:res_state, status, []})
    {:res_state, res_status, res_packs} = result_question
    # Формируем полный стейт
    %{
      "status" => res_status,
      "categories" => categories,
      "resources" => resources,
      "all_packs" => res_packs
    }
  end

  # Клауз закрытия для опроса GitHub
  defp questionStatus([], acc) do
    {:res_state, _res_status, res_packs} = acc
    {:res_state, "checked", res_packs}
  end

  # Основной рабочий клауз для опроса GitHub
  defp questionStatus([head | tail], acc) do
    try do
      %{link: one_link, stars: one_stars, lastupdate: one_lu} = head

      if one_stars == 0 and one_lu == 0 do
        one_link_repos =
          String.replace(
            one_link,
            "https://github.com/",
            "https://fb-qt-elixir:Fmk9h0mda@api.github.com/repos/",
            global: false
          )

        %HTTPoison.Response{body: lines} = HTTPoison.get!(one_link_repos)
        {status, response_gha} = Jason.decode(lines)

        acc2 =
          if status == :ok do
            {resp_updated, resp_stars, stat_active} =
              case response_gha do
                %{"commits_url" => resp_commits_url, "stargazers_count" => resp_stars} ->
                  {getCommitUpdated(resp_commits_url), resp_stars, 1}

                %{"documentation_url" => _doc_url_GH, "message" => _mes_gh, "url" => url_gh} ->
                  one_link_repos =
                    String.replace(
                      url_gh,
                      "https://api.github.com/",
                      "https://fb-qt-elixir:Fmk9h0mda@api.github.com/",
                      global: false
                    )

                  %HTTPoison.Response{body: lines} = HTTPoison.get!(one_link_repos)
                  {_status, response_gha} = Jason.decode(lines)

                  %{"commits_url" => resp_commits_url, "stargazers_count" => resp_stars} =
                    response_gha

                  {getCommitUpdated(resp_commits_url), resp_stars, 1}

                %{"documentation_url" => _doc_url_gh, "message" => _mes_gh} ->
                  {0, 0, 0}

                _ ->
                  {0, 0, 0}
              end

            if stat_active != 0 do
              {:ok, resp_updated_dt, 0} = DateTime.from_iso8601(resp_updated)

              days_passed =
                div(
                  DateTime.to_unix(DateTime.now!("Etc/UTC")) -
                    DateTime.to_unix(resp_updated_dt),
                  86400
                )

              Logger.info("Package information updated: #{inspect(one_link)}")
              one_res = %{head | stars: resp_stars, lastupdate: days_passed}
              {:res_state, res_status, res_packs} = acc
              res_packs = res_packs ++ [one_res]
              {:res_state, res_status, res_packs}
            else
              # Непроверяемый пакет идем дальше
              acc
            end
          else
            # Непроверяемый пакет идем дальше
            acc
          end

        # Отработало подключение идем дальше по пакетам
        questionStatus(tail, acc2)
      else
        {:res_state, res_status, res_packs} = acc
        res_packs = res_packs ++ [head]
        acc2 = {:res_state, res_status, res_packs}
        questionStatus(tail, acc2)
      end
    rescue
      _e -> questionStatus(tail, acc)
    end
  end

  # Получить дату последнего обновления последнего коммита
  defp getCommitUpdated(url) do
    try do
      one_link_repos =
        String.replace(url, "https://", "https://fb-qt-elixir:Fmk9h0mda@", global: false)

      one_link_first_commit = String.replace(one_link_repos, "{/sha}", "")
      %HTTPoison.Response{body: lines} = HTTPoison.get!(one_link_first_commit)
      {status, response_gha} = Jason.decode(lines)

      if status == :ok do
        [head_response_gha | _tail] = response_gha
        %{"commit" => %{"committer" => %{"date" => resp_updated}}} = head_response_gha
        resp_updated
      else
        DateTime.to_string(DateTime.now!("Etc/UTC"))
      end
    rescue
      _e -> DateTime.to_string(DateTime.now!("Etc/UTC"))
    end
  end

  @doc """
  	Проверка совпадений спаска категорий со списком найденных пакетов
  	и возврат актуального списка categories.
    Используется для выборки из хранилища при отображении страницы, для парсинга НЕ используется.
  """
  def checkForMatches(categories, all_packs) do
    list_heading =
      for one_pack <- all_packs do
        %{:heading => heading} = one_pack
        heading
      end

    list_heading = Enum.uniq(list_heading)

    categories =
      for category <- categories do
        Enum.find_value(list_heading, fn x -> if x == category.title, do: category end)
      end

    Enum.reject(categories, fn x -> x == nil end)
  end
end
