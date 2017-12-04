defmodule SanbaseWeb.Router do
  use SanbaseWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :basic_auth do
    plug BasicAuth, use_config: {:ex_admin, :basic_auth}
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug SanbaseWeb.Graphql.ContextPlug
  end

  pipeline :nextjs do
    plug :accepts, ["html"]
    plug :put_secure_browser_headers
  end

  use ExAdmin.Router
  scope "/admin", ExAdmin do
    pipe_through [:browser, :basic_auth]
    admin_routes()
  end

  scope "/" do
    pipe_through :api

    forward "/graphql", Absinthe.Plug,
      schema: SanbaseWeb.Graphql.Schema
  end

  scope "/api", SanbaseWeb do
    pipe_through :api

    resources "/cashflow", CashflowController, only: [:index]
    resources "/daily_prices", DailyPricesController, only: [:index]
  end

  scope "/api", SanbaseWeb do
    pipe_through [:api, :basic_auth]

    resources "/projects", ProjectsController, only: [:index]
  end

  scope "/" do
    pipe_through [:nextjs]

    get "/*path", ReverseProxy, upstream: [Application.fetch_env!(:sanbase, :node_server)]
  end
end
