use Mix.Config

# For production, don't forget to configure the url host
# to something meaningful, Phoenix uses this information
# when generating URLs.
#
# Note we also include the path to a cache manifest
# containing the digested version of static files. This
# manifest is generated by the `mix phx.digest` task,
# which you should run after static files are built and
# before starting your production server.
config :funbox_qt_elixir, FunboxQtElixirWeb.Endpoint,
  url: [host: "example.com", port: 80],
  cache_static_manifest: "priv/static/cache_manifest.json"

# Do not print debug messages in production
config :logger, level: :info

config :funbox_qt_elixir, :children, [
  # Start the Telemetry supervisor
  FunboxQtElixirWeb.Telemetry,
  # Start the PubSub system
  {Phoenix.PubSub, name: FunboxQtElixir.PubSub},
  # Start the Endpoint (http/https)
  FunboxQtElixirWeb.Endpoint,
  # FunboxQtElixir.AwesomeServer for state of awesome-list
  FunboxQtElixir.AwesomeServer
]

# Количество потоков для обновления данных
config :funbox_qt_elixir, :count_flow, 10

# Логин для доступа к GitHub API
config :funbox_qt_elixir, :login_gha, "fb-qt-elixir"

# Токен для доступа к GitHub API (токен удаляется через 1 год после последнего использования)
config :funbox_qt_elixir, :token_gha, "5a0c0820016e104363923dac3dbb2a49cd1cd639"

# ## SSL Support
#
# To get SSL working, you will need to add the `https` key
# to the previous section and set your `:url` port to 443:
#
#     config :funbox_qt_elixir, FunboxQtElixirWeb.Endpoint,
#       ...
#       url: [host: "example.com", port: 443],
#       https: [
#         port: 443,
#         cipher_suite: :strong,
#         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
#         certfile: System.get_env("SOME_APP_SSL_CERT_PATH"),
#         transport_options: [socket_opts: [:inet6]]
#       ]
#
# The `cipher_suite` is set to `:strong` to support only the
# latest and more secure SSL ciphers. This means old browsers
# and clients may not be supported. You can set it to
# `:compatible` for wider support.
#
# `:keyfile` and `:certfile` expect an absolute path to the key
# and cert in disk or a relative path inside priv, for example
# "priv/ssl/server.key". For all supported SSL configuration
# options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
#
# We also recommend setting `force_ssl` in your endpoint, ensuring
# no data is ever sent via http, always redirecting to https:
#
#     config :funbox_qt_elixir, FunboxQtElixirWeb.Endpoint,
#       force_ssl: [hsts: true]
#
# Check `Plug.SSL` for all available options in `force_ssl`.

# Finally import the config/prod.secret.exs which loads secrets
# and configuration from environment variables.
import_config "prod.secret.exs"
