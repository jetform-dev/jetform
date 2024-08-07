# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :app,
  app_name: "JetForm",
  app_tagline: "JetForm",
  default_tz: "Asia/Jakarta",
  default_tz_label: "WIB",
  order_validity_hours: 2,
  access_validity_days: 7,
  withdrawal_fee: 5_000,
  default_plan: App.Plans.Commission5,
  payment_provider: App.PaymentGateway.Ipaymu,
  enable_subdomain: true

config :app, :midtrans,
  enabled_payments: ["permata_va", "bca_va", "bni_va", "bri_va", "cimb_va", "other_qris"]

config :app, :ipaymu, payment_method: "auto"

config :app,
  ecto_repos: [App.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true]

# Configures the endpoint
config :app, AppWeb.Endpoint,
  url: [host: "jetform.local"],
  adapter: Phoenix.Endpoint.Cowboy2Adapter,
  render_errors: [
    formats: [html: AppWeb.ErrorHTML, json: AppWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: App.PubSub,
  live_view: [signing_salt: "CKtWJArt"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :app, App.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.3.2",
  default: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :app, :pow,
  web_module: AppWeb,
  user: App.Users.User,
  repo: App.Repo,
  extensions: [PowResetPassword, PowEmailConfirmation],
  controller_callbacks: Pow.Extension.Phoenix.ControllerCallbacks,
  cache_store_backend: AppWeb.PowRedisCache,
  mailer_backend: App.Mailer,
  routes_backend: AppWeb.PowAuthRoutes,
  messages_backend: AppWeb.PowAuthMessages

config :waffle,
  storage: Waffle.Storage.Local,
  storage_dir_prefix: "priv/static",
  storage_dir: "uploads"

config :flop,
  repo: App.Repo

config :app, Oban,
  repo: App.Repo,
  plugins: [Oban.Plugins.Pruner],
  queues: [default: 10]

config :tesla, :adapter, {Tesla.Adapter.Finch, name: App.Finch, receive_timeout: 30_000}

# asset_host: "http://localhost:4000"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
