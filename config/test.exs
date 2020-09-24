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
