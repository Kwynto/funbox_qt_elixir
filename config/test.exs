use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :funbox_qt_elixir, FunboxQtElixirWeb.Endpoint,
  http: [port: 4002],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

config :funbox_qt_elixir, :children, [
  # Start the Telemetry supervisor
  FunboxQtElixirWeb.Telemetry,
  # Start the PubSub system
  {Phoenix.PubSub, name: FunboxQtElixir.PubSub},
  # Start the Endpoint (http/https)
  FunboxQtElixirWeb.Endpoint
  # Start a worker by calling: FunboxQtElixir.Worker.start_link(arg)
  # {FunboxQtElixir.Worker, arg}
]

# Количество потоков для обновления данных
config :funbox_qt_elixir, :count_flow, 10

# Логин для доступа к GitHub API
config :funbox_qt_elixir, :login_gha, "fb-qt-elixir"

# Токен для доступа к GitHub API (токен удаляется через 1 год после последнего использования)
config :funbox_qt_elixir, :token_gha, "5a0c0820016e104363923dac3dbb2a49cd1cd639"
