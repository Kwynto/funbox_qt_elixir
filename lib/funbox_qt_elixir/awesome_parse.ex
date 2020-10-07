defmodule FunboxQtElixir.AwesomeParse do
  @moduledoc """
    Модуль для обработки h4cc/awesome-elixir.
    Загрузка и парсинг во внтренний формат.
  """

  # #####################
  # Регулярные выражения
  # #####################

  # регулярное выражение для парсинга пакета, используется в parse_line/1
  @line_regex ~r/^\[([^]]+)\]\(([^)]+)\) - (.+)([\.\!]+)$/

  # регулярное выражение для описания пакета, 
  # используется в division_description?/1 и division_description/1
  @description_regex ~r/^(.+)\[([^]]+)\]\(([^)]+)\)(.+)$/

  # #################
  # Функции парсинга
  # #################

  @doc """
    Точка входа.
    Загрузка awesom-list в формате MD и парсинг в удобный внутренний формат.
  """
  @spec run_parse() :: %{categories: list(), resources: list(), all_packs: list()}
  def run_parse() do
    # скачиваем список пакетов
    %HTTPoison.Response{body: lines} =
      HTTPoison.get!("https://raw.githubusercontent.com/h4cc/awesome-elixir/master/README.md")

    # Парсим загруженный MD-файл
    parse_awesome_list(lines)
  end

  @doc """
    Парсим весь входящий awesom-list в формате MD.
    Входящие данный: скачанные или загруженные из файла данные.
    Исходящеи данный: ассоциативный массив %{"categories" => categories, "resources" => resources, "all_packs" => all_packs}
      каждое поле является списком,
      categories - список с категориями, каждая категория в формате %{:title => title, :link => link, :description => ""},
      resources - список с ресурсами, каждый ресурс в формате  %{:title => title, :link => link, :description => ""},
      all_packs - список пакетов из awesom-list = список ассоциативных массивов (maps),
        где каждая мапа описывает конкретный пакет в формате
         %{
          :name => name,
          :link => link,
          :description => description,
          :heading => heading,
          :stars => 0,
          :lastupdate => 0
          }
          где: 
            name - (string) имя пакета,
            link - (string) ссылка,
            description - (string) описание пакета, 
            heading - (string) к какому заголовку относится (соответствует названию в categories или в resources),
            stars - (integer) количество звезд на GitHub (default = 0),
            lastupdate - (integer) количество дней с последнего обновленя (default = 0)
  """
  @spec parse_awesome_list(String.t()) :: %{
          categories: list(),
          resources: list(),
          all_packs: list()
        }
  def parse_awesome_list(lines) do
    # Делим на блоки
    {blocks, _links, _options} = EarmarkParser.Parser.parse(String.split(lines, ~r{\r\n?|\n}))

    # Убеждаемся что есть заголовок и отбрасываем его
    [%EarmarkParser.Block.Heading{} | blocks] = blocks

    # Отбрасываем лишние заголовочные и описательные блоки
    [_intro | blocks] = blocks
    [_like | blocks] = blocks
    [_other | blocks] = blocks

    # Получаем список с содержанием и остаток содержимого для оснвогого тела
    [%EarmarkParser.Block.List{blocks: table_of_content} | blocks_list] = blocks

    # Выделяем категории
    [
      %EarmarkParser.Block.ListItem{blocks: [%EarmarkParser.Block.Text{} | categories]}
      | table_of_content
    ] = table_of_content

    [%EarmarkParser.Block.List{blocks: categories}] = categories

    # Парсим содержание на категории
    categories =
      for %EarmarkParser.Block.ListItem{blocks: [%EarmarkParser.Block.Text{line: [name]}]} <-
            categories do
        {title, link} = parse_markdown_link(name)
        link = String.replace(link, "#", "")
        %{title: title, link: link, description: ""}
      end

    # Выделяем блок ресурсов
    [
      %EarmarkParser.Block.ListItem{blocks: [%EarmarkParser.Block.Text{} | resources]}
      | _table_of_content
    ] = table_of_content

    [%EarmarkParser.Block.List{blocks: resources}] = resources

    # Парсим остаток загловков для блока ресурсов
    resources =
      for %EarmarkParser.Block.ListItem{blocks: [%EarmarkParser.Block.Text{line: [name]}]} <-
            resources do
        {title, link} = parse_markdown_link(name)
        link = String.replace(link, "#", "")
        %{title: title, link: link, description: ""}
      end

    # Парсим основной контент
    # и дополнительно вытягиваем описания категорий.
    # Для получения двух значений за один проход используем кортеж на выходе
    {:combopack, all_packs, categories} = iterate_content(blocks_list, [], categories)

    # пересобираем пакеты через unblocking_content так, чтобы небыло следов 
    # от многоуровневых вложений, если они были и делаем реверс списка
    all_packs =
      all_packs
      |> unblocking_content([])
      |> Enum.reverse()

    # Формируем полный ответ
    %{
      categories: categories,
      resources: resources,
      all_packs: all_packs
    }
  end

  # Разделение тегов заголовка вида [title](link) на имя и ссылку
  @spec parse_markdown_link(String.t()) :: {String.t(), String.t()}
  defp parse_markdown_link(string) do
    [^string, title, link] = Regex.run(~r/\[(.+)\]\((.+)\)/, string)
    {title, link}
  end

  # Удаляем внтренние массивы, отавшиеся от старой структуры из MD
  # Клауза выхода, БЕЗ реверса
  @spec unblocking_content(list(), list()) :: list()
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

  # Добавление мапы с описанием пакета в результирующий список
  defp unblocking_content(map, acc) do
    [map | acc]
  end

  # Переборка основного тела со списком пакетов
  # ---
  # Клауза для выхода из функции и реверс результата
  @spec iterate_content(list(), list(), list()) :: {:combopack, list(), list()}
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
  @spec check_list(list(), String.t()) :: list()
  defp check_list(list, heading) do
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

      [name, link, description | _rest] = parse_line(line)

      %{
        name: name,
        link: link,
        description: description,
        heading: heading,
        stars: 0,
        lastupdate: 0
      }
    end
  end

  # Парсим строку пакета на: имя, ссылку и описание (через регулярное выражение)
  defp parse_line(line) do
    case Regex.run(@line_regex, line) do
      nil -> raise("Line does not match format: '#{line}' Is there a dot at the end?")
      [^line, name, link, description, dot] -> [name, link, " " <> description <> dot]
    end
  end

  # #################################
  # Дополнительные сервисные функции
  # #################################

  @doc """
    Парсим строку описания на наличие дополнительной ссылки на технологию (через регулярное выражение)
    Используется в шаблоне.
  """
  def division_description(description) do
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
  def division_description?(description) do
    case Regex.run(@description_regex, description) do
      nil -> false
      [^description, _begin_str, _name, _link, _end_str] -> true
    end
  end
end
