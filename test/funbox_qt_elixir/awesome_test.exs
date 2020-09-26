defmodule FunboxQtElixir.AwesomeTest do
  use FunboxQtElixir.AwesomeCase

  test "Loading awesome-list" do
    result = FunboxQtElixir.Awesome.runParse()
    %{"status" => status} = result
    assert status == "loaded"
  end

  test "Parse awesome-list" do
    %HTTPoison.Response{body: lines} =
      HTTPoison.get!("https://raw.githubusercontent.com/h4cc/awesome-elixir/master/README.md")

    result = FunboxQtElixir.Awesome.parseAwesomeList(lines)
    %{"status" => status} = result
    assert status == "loaded"
  end

  test "Parse description without links" do
    description = " Any description"
    result = FunboxQtElixir.Awesome.divisionDescription(description)
    assert result == description
  end

  test "Parse description with links" do
    description = " Begin description [somelink](http://localhost/) end description."
    result = FunboxQtElixir.Awesome.divisionDescription(description)

    assert result ==
             {:description, " Begin description ", "http://localhost/", "somelink",
              " end description."}
  end

  test "Description has not links 1" do
    description = " Any description"
    assert FunboxQtElixir.Awesome.divisionDescription?(description) == false
  end

  test "Description has not links 2" do
    description = " Any description"
    refute FunboxQtElixir.Awesome.divisionDescription?(description) == true
  end

  test "Description has links 1" do
    description = " Begin description [somelink](http://localhost/) end description."
    assert FunboxQtElixir.Awesome.divisionDescription?(description) == true
  end

  test "Description has links 2" do
    description = " Begin description [somelink](http://localhost/) end description."
    refute FunboxQtElixir.Awesome.divisionDescription?(description) == false
  end

  test "Parse data from GitHub API" do
    data = %{
      "status" => "loaded",
      "categories" => [],
      "resources" => [],
      "all_packs" => [
        %{
          :name => "fsm",
          :link => "https://github.com/sasa1977/fsm",
          :description => "Finite state machine as a functional data structure. ",
          :heading => "Algorithms and Data structures",
          :stars => 0,
          :lastupdate => 0
        }
      ]
    }

    result = FunboxQtElixir.Awesome.questionGitHubData(data)

    %{
      "status" => status,
      "categories" => _categories,
      "resources" => _resources,
      "all_packs" => all_packs
    } = result

    [%{:stars => stars, :lastupdate => lu}] = all_packs

    assert status == "checked"
    refute status == "loaded"
    assert is_integer(stars) == true
    assert is_integer(lu) == true
    refute is_integer(stars) == false
    refute is_integer(lu) == false
  end

  test "Check for matches" do
    categories = [
      %{
        :title => "Algorithms and Data structures",
        :link => "algorithms-and-data-structures",
        :description => ""
      },
      %{
        :title => "Any head",
        :link => "any-link-head",
        :description => ""
      }
    ]

    all_packs = [
      %{
        :name => "fsm",
        :link => "https://github.com/sasa1977/fsm",
        :description => "Finite state machine as a functional data structure. ",
        :heading => "Algorithms and Data structures",
        :stars => 0,
        :lastupdate => 0
      }
    ]

    result = FunboxQtElixir.Awesome.checkForMatches(categories, all_packs)

    assert result == [
             %{
               :title => "Algorithms and Data structures",
               :link => "algorithms-and-data-structures",
               :description => ""
             }
           ]

    refute result == [%{:title => "Any head", :link => "any-link-head", :description => ""}]
    refute result == categories
  end
end
