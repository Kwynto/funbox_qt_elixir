defmodule FunboxQtElixir.AwesomeProbing do
  @moduledoc """
    Опрос GitHub на актуальную информацию и обновление состояний пакетов.
  """

  require Logger

  @doc """
    Опрос GitHub через GitHub API для получения у конкретного пакета количества звезд и даты последнего обновления
    Входящие данные: пакет и номер потока
    Результат: обновленный пакет или nil
  """
  @spec enquiry_github_data_via_api(map(), integer()) :: any()
  def enquiry_github_data_via_api(%{link: link} = pack, flow_num \\ 0) do
    try do
      if String.contains?(link, "github.com/") do
        # получаем из конфигурации данные для авторизации на GitHub API
        auth = Application.get_env(:funbox_qt_elixir, :auth_gha)

        # формируем запрос к GitHub API из ссылки пакета
        link_repos =
          String.replace(
            link,
            "https://github.com/",
            "https://" <> auth <> "@api.github.com/repos/",
            global: false
          )

        # делаем запрос и декодируем JSON
        %HTTPoison.Response{body: lines} = HTTPoison.get!(link_repos)
        {:ok, response_gha} = Jason.decode(lines)

        {resp_updated, resp_stars, stat_active} =
          case response_gha do
            %{"commits_url" => resp_commits_url, "stargazers_count" => resp_stars} ->
              # корректный ответ запрашивем дату последнего обновления из коммитов
              # и возвращаем кортеж {дата, звезды, признак_удачного_завершения}
              {get_commit_updated(resp_commits_url), resp_stars, 1}

            %{"documentation_url" => _doc_url_GH, "message" => _mes_gh, "url" => url_gh} ->
              # некорректный ответ, репозиторий перемещен или переименован
              # получаем актуальный адрес из сообщения и опять проверяем как это было выше
              link_repos =
                String.replace(
                  url_gh,
                  "https://api.github.com/",
                  "https://" <> auth <> "@api.github.com/",
                  global: false
                )

              %HTTPoison.Response{body: lines} = HTTPoison.get!(link_repos)
              {_status, response_gha} = Jason.decode(lines)

              %{"commits_url" => resp_commits_url, "stargazers_count" => resp_stars} =
                response_gha

              # возвращаем кортеж {дата, звезды, признак_удачного_завершения}
              {get_commit_updated(resp_commits_url), resp_stars, 1}

            %{"documentation_url" => _doc_url_gh, "message" => _mes_gh} ->
              # GitHub сообщил о невозможности проверить несуществующий репозиторий
              # возможно он удален
              # формируем кортеж по общей схеме, последний элемент показывает провал проверки
              {0, 0, 0}

            _ ->
              # общее правило для всех прочих ответов отличных от корректных
              # формируем кортеж по общей схеме, последний элемент показывает провал проверки
              {0, 0, 0}
          end

        # если проверка прошла успешно (stat_active последний элемент кортежа результата проверки),
        # то формируем ответ
        if stat_active != 0 do
          # конвертируем полученную дату и время в DateTime
          {:ok, resp_updated_dt, 0} = DateTime.from_iso8601(resp_updated)

          # вычисляем количество дней, прошедших с последнего обновленя
          days_passed =
            div(
              DateTime.to_unix(DateTime.now!("Etc/UTC")) -
                DateTime.to_unix(resp_updated_dt),
              86400
            )

          Logger.info("[Flow № #{flow_num}] Package information updated: #{inspect(link)}")

          # обновляем мапу и возвращаем ее в качестве результата всей проверки
          %{pack | stars: resp_stars, lastupdate: days_passed}
        else
          # Непроверяемый пакет возвращаем nil
          nil
        end
      else
        # ссылка вела не на GitHub
        # Непроверяемый пакет возвращаем nil
        Logger.debug("[Flow № #{flow_num}] Not GitHub resource: #{inspect(link)}")
        nil
      end
    rescue
      _e ->
        Logger.error("[Flow № #{flow_num}] Connection error: #{inspect(link)}. REPEAT!")
        enquiry_github_data_via_api(pack, flow_num)
    end
  end

  # Получить дату последнего обновления последнего коммита через GitHub API
  # в виде строки (то есть так как приходит с GitHub)
  @spec get_commit_updated(String.t()) :: String.t()
  defp get_commit_updated(url) do
    try do
      # получаем из конфигурации данные для авторизации на GitHub API
      auth = Application.get_env(:funbox_qt_elixir, :auth_gha)

      # формируем адрес для запроса информации о коммитах
      link_repos = String.replace(url, "https://", "https://" <> auth <> "@", global: false)
      link_commits = String.replace(link_repos, "{/sha}", "")

      # запрашиваем информацию о всех коммитах
      %HTTPoison.Response{body: lines} = HTTPoison.get!(link_commits)
      {status, response_gha} = Jason.decode(lines)

      if status == :ok do
        # если запрос прошел успешно, то получаем из ответа последний коммит
        [last_commit | _tail] = response_gha
        # получаем из коммита его дату и время обновления
        %{"commit" => %{"committer" => %{"date" => resp_updated}}} = last_commit
        resp_updated
      else
        # если запрос провалился, то возвращаем текущие дату и время как строку
        DateTime.to_string(DateTime.now!("Etc/UTC"))
      end
    rescue
      _e -> DateTime.to_string(DateTime.now!("Etc/UTC"))
    end
  end

  @doc """
    Опрос GitHub через Floki для получения у конкретного пакета количества звезд и даты последнего обновления
    Входящие данные: пакет и номер потока
    Результат: обновленный пакет или nil
    !!! Это альтернативный метод запросов к GitHub !!!
  """
  @spec enquiry_github_data_via_floki(map(), integer()) :: any()
  def enquiry_github_data_via_floki(%{link: link} = pack, flow_num \\ 0) do
    # делаем задержку в выполнении (только для этого режима), 
    # так как при прямых запросах можно получить блокировку от GitHub
    :timer.sleep(61_000)

    # приступаем к работе

    try do
      if String.contains?(link, "github.com/") do
        # делаем запрос и получаем документ
        %HTTPoison.Response{body: lines} = HTTPoison.get!(link)
        {:ok, document} = Floki.parse_document(lines)

        # получаем строку с количеством звезд и сопроводительным текстом
        [_head | [stars_aria_label | _tail]] =
          document
          |> Floki.find("a.social-count")
          |> Floki.attribute("aria-label")

        # получаем количество звезд
        [resp_stars | _tail] = String.split(stars_aria_label, " ", trim: true)
        resp_stars = String.to_integer(resp_stars)

        # получаем дату и время обновления последнего коммита
        [resp_updated | _tail] =
          document
          |> Floki.find("relative-time")
          |> Floki.attribute("datetime")

        # конвертируем полученную дату и время в DateTime
        {:ok, resp_updated_dt, 0} = DateTime.from_iso8601(resp_updated)

        # вычисляем количество дней, прошедших с последнего обновленя
        days_passed =
          div(
            DateTime.to_unix(DateTime.now!("Etc/UTC")) -
              DateTime.to_unix(resp_updated_dt),
            86400
          )

        Logger.info("[Flow № #{flow_num}] Package information updated: #{inspect(link)}")

        # обновляем мапу и возвращаем ее в качестве результата всей проверки
        %{pack | stars: resp_stars, lastupdate: days_passed}
      else
        # ссылка вела не на GitHub
        # Непроверяемый пакет возвращаем nil
        Logger.debug("[Flow № #{flow_num}] Not GitHub resource: #{inspect(link)}")
        nil
      end
    rescue
      _e ->
        # Ошибка соединения. Повторить.
        enquiry_github_data_via_floki(pack, flow_num)
    end
  end

  @doc """
    Проверка совпадений списка категорий со списком найденных пакетов
    и возврат актуального списка categories.
    Используется для выборки из хранилища при отображении страницы, для парсинга и опроса НЕ используется.
  """
  @spec check_for_matches(list(), list()) :: list()
  def check_for_matches(categories, all_packs) do
    list_heading =
      for one_pack <- all_packs do
        %{heading: heading} = one_pack
        heading
      end

    list_heading = Enum.uniq(list_heading)

    categories =
      for category <- categories do
        Enum.find_value(list_heading, fn x -> if x == category.title, do: category end)
      end

    Enum.reject(categories, fn x -> x == nil end)
  end

  @doc """
    Разделение всего списка пакетов на списки для потоков
    packs - список всех пакетов
    count - количество потоков
  """
  @spec div_list(list(), integer()) :: list()
  def div_list(packs, count) do
    # формируем начальное состояние аккумулятора для разделения данных на потоки
    acc = for item <- 1..count, into: %{}, do: {item, []}

    # начинаем разделение данных для паралельных потоков
    div_list(packs, count, acc, 1)
  end

  # Выход
  def div_list([], _count, acc, _next) do
    acc
  end

  # Переборка
  def div_list(packs, count, acc, next) do
    # берем очередныой пакет
    [head | tail] = packs
    # получаем аккумулятор очередного потока
    %{^next => work_arr} = acc
    # добавляем пакет в аккумулятор потока
    work_arr = [head | work_arr]
    # обновляем полный аккумулятор
    acc = %{acc | next => work_arr}

    # Переходим к аккумулятору следующего потока
    if next == count do
      # если счетчик достиг максимума, то переходим к первому аккумулятору
      div_list(tail, count, acc, 1)
    else
      # счетчик ещё не максимальный, 
      # увеличиваем на единицу для перехода к следующему аккумулятору
      div_list(tail, count, acc, next + 1)
    end
  end
end
