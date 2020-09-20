defmodule FunboxQtElixirWeb.PageControllerTest do
	use FunboxQtElixirWeb.ConnCase

	describe "Asserts" do

		test "GET /", %{conn: conn} do
			conn = get(conn, "/")
			assert html_response(conn, 200) =~ "Awesome Elixir"
		end

		test "GET /?min_stars=10", %{conn: conn} do
			conn = get(conn, "/?min_stars=10")
			assert html_response(conn, 200) =~ "Awesome Elixir"
		end

		test "GET /?min_stars=50", %{conn: conn} do
			conn = get(conn, "/?min_stars=10")
			assert html_response(conn, 200) =~ "Awesome Elixir"
		end

		test "GET /?min_stars=100", %{conn: conn} do
			conn = get(conn, "/?min_stars=10")
			assert html_response(conn, 200) =~ "Awesome Elixir"
		end

		test "GET /?min_stars=500", %{conn: conn} do
			conn = get(conn, "/?min_stars=10")
			assert html_response(conn, 200) =~ "Awesome Elixir"
		end

		test "GET /?min_stars=1000", %{conn: conn} do
			conn = get(conn, "/?min_stars=10")
			assert html_response(conn, 200) =~ "Awesome Elixir"
		end
	end

	describe "Refutes" do

		test "GET /", %{conn: conn} do
			conn = get(conn, "/")
			refute html_response(conn, 200) =~ "Welcome to Phoenix!"
		end

		test "GET /?min_stars=10", %{conn: conn} do
			conn = get(conn, "/?min_stars=10")
			refute html_response(conn, 200) =~ "Create a pool based on a hash ring"
		end

		test "GET /?min_stars=50", %{conn: conn} do
			conn = get(conn, "/?min_stars=50")
			refute html_response(conn, 200) =~ "Aruspex is a configurable constraint solver, written purely in Elixir"
		end

		test "GET /?min_stars=100", %{conn: conn} do
			conn = get(conn, "/?min_stars=100")
			refute html_response(conn, 200) =~ "A pure Elixir implementation of Scalable Bloom"
		end

		test "GET /?min_stars=500", %{conn: conn} do
			conn = get(conn, "/?min_stars=500")
			refute html_response(conn, 200) =~ "A collection of protocols, implementations and wrappers"
		end

		test "GET /?min_stars=1000", %{conn: conn} do
			conn = get(conn, "/?min_stars=1000")
			refute html_response(conn, 200) =~ "Isaac is an elixir module for ISAAC: a fast cryptographic random"
		end
	end

end
