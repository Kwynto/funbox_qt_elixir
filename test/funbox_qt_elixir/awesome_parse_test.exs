defmodule FunboxQtElixir.AwesomeParseTest do
  use FunboxQtElixir.AwesomeCase

  test "Loading awesome-list" do
    result = FunboxQtElixir.AwesomeParse.run_parse()
    %{"status" => status} = result
    assert status == "loaded"
  end

  test "Parse awesome-list" do
    %HTTPoison.Response{body: lines} =
      HTTPoison.get!("https://raw.githubusercontent.com/h4cc/awesome-elixir/master/README.md")

    result = FunboxQtElixir.AwesomeParse.parse_awesome_list(lines)
    %{"status" => status} = result
    assert status == "loaded"
  end

  test "Parse description without links" do
    description = " Any description"
    result = FunboxQtElixir.AwesomeParse.division_description(description)
    assert result == description
  end

  test "Parse description with links" do
    description = " Begin description [somelink](http://localhost/) end description."
    result = FunboxQtElixir.AwesomeParse.division_description(description)

    assert result ==
             {:description, " Begin description ", "http://localhost/", "somelink",
              " end description."}
  end

  test "Description has not links 1" do
    description = " Any description"
    assert FunboxQtElixir.AwesomeParse.division_description?(description) == false
  end

  test "Description has not links 2" do
    description = " Any description"
    refute FunboxQtElixir.AwesomeParse.division_description?(description) == true
  end

  test "Description has links 1" do
    description = " Begin description [somelink](http://localhost/) end description."
    assert FunboxQtElixir.AwesomeParse.division_description?(description) == true
  end

  test "Description has links 2" do
    description = " Begin description [somelink](http://localhost/) end description."
    refute FunboxQtElixir.AwesomeParse.division_description?(description) == false
  end
end
