# This file is responsible for configuring your umbrella
# and **all applications** and their dependencies with the
# help of the Config module.
#
# Note that all applications in your umbrella share the
# same configuration and dependencies, which is why they
# all use the same configuration file. If you want different
# configurations or dependencies per app, it is best to
# move said applications out of the umbrella.
import Config

# Configure Mix tasks and generators
config :cyber_core,
  ecto_repos: [CyberCore.Repo]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :cyber_core, CyberCore.Mailer, adapter: Swoosh.Adapters.Local

config :cyber_web,
  ecto_repos: [CyberCore.Repo],
  generators: [context_app: :cyber_core]

# Configures the endpoint
config :cyber_web, CyberWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Phoenix.Endpoint.Cowboy2Adapter,
  render_errors: [
    formats: [json: CyberWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: CyberCore.PubSub,
  live_view: [signing_salt: "cHiH+tyz"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../apps/cyber_web/assets", __DIR__),
    env: %{
      "NODE_PATH" => Path.expand("../deps", __DIR__),
      "PATH" => System.get_env("PATH")
    }
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
    cd: Path.expand("../apps/cyber_web/assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# ============================================================================
# Azure Form Recognizer & S3 Storage Configuration
# ============================================================================
#
# ВАЖНО: Credentials за Azure Form Recognizer и S3 Hetzner Storage се
# съхраняват в базата данни (таблица integration_settings), а не тук!
#
# Конфигурирайте ги чрез:
# - UI: http://localhost:4000/settings (секция "AI и Cloud Интеграции")
# - IEx: CyberCore.Settings.upsert_azure_form_recognizer(tenant_id, endpoint, api_key)
# - IEx: CyberCore.Settings.upsert_s3_storage(tenant_id, access_key, secret_key, host, bucket)
#
# Вижте docs/SETUP_CREDENTIALS.md за повече информация.
# ============================================================================

# Configure ExAws (used by S3Client) - само базови настройки
config :ex_aws,
  json_codec: Jason,
  region: "eu-central"

config :ex_aws, :s3,
  scheme: "https://",
  port: 443

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
