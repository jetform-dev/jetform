defmodule AppWeb.SubdomainRouter do
  use AppWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {AppWeb.Layouts, :root}
    plug :put_layout, html: {AppWeb.Layouts, :storefront}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug AppWeb.Plugs.PutTenant
  end

  scope "/", AppWeb.Subdomain do
    pipe_through :browser

    get "/:slug", PageController, :show
    get "/", PageController, :index
  end
end
