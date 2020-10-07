defmodule FunboxQtElixir.AwesomeProbingTest do
  use FunboxQtElixir.AwesomeCase

  test "Question data from GitHub API" do
    pack = %{
      name: "fsm",
      link: "https://github.com/sasa1977/fsm",
      description: "Finite state machine as a functional data structure. ",
      heading: "Algorithms and Data structures",
      stars: 0,
      lastupdate: 0
    }

    result = FunboxQtElixir.AwesomeProbing.enquiry_github_data_via_api(pack, 1)

    %{stars: stars, lastupdate: lu} = result

    assert is_integer(stars) == true
    assert is_integer(lu) == true
    refute is_integer(stars) == false
    refute is_integer(lu) == false
  end

  test "Check for matches" do
    categories = [
      %{
        title: "Algorithms and Data structures",
        link: "algorithms-and-data-structures",
        description: ""
      },
      %{
        title: "Any head",
        link: "any-link-head",
        description: ""
      }
    ]

    all_packs = [
      %{
        name: "fsm",
        link: "https://github.com/sasa1977/fsm",
        description: "Finite state machine as a functional data structure. ",
        heading: "Algorithms and Data structures",
        stars: 0,
        lastupdate: 0
      }
    ]

    result = FunboxQtElixir.AwesomeProbing.check_for_matches(categories, all_packs)

    assert result == [
             %{
               title: "Algorithms and Data structures",
               link: "algorithms-and-data-structures",
               description: ""
             }
           ]

    refute result == [%{title: "Any head", link: "any-link-head", description: ""}]
    refute result == categories
  end

  test "Splitting the package list into streams" do
    # получаем все пакеты
    map_result = FunboxQtElixir.AwesomeParse.run_parse()
    %{all_packs: all_packs} = map_result

    # Получаем количество потоков из конфигурации
    count_flow = Application.get_env(:funbox_qt_elixir, :count_flow)

    # разделение списка всех пакетов на списки для потоков
    div_packs = FunboxQtElixir.AwesomeProbing.div_list(all_packs, count_flow)
    %{1 => list1} = div_packs

    assert is_map(div_packs) == true
    assert is_list(list1) == true
  end
end
