defmodule FunboxQtElixir.AwesomeCase do
	@moduledoc """
		Этот модуль подготовки тестирования.
	"""

	use ExUnit.CaseTemplate

	setup _tags do
		{:ok, conn: Phoenix.ConnTest.build_conn()}
	end
end
