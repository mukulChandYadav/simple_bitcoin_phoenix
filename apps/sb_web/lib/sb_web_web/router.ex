defmodule SbWebWeb.Router do
  use SbWebWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", SbWebWeb do
    pipe_through :browser

    get "/", PageController, :index

    get "/sb", SBController, :index

    get "/sb/tx", SBController, :tx

    get "/sb/simulation", SBController, :simulate

  end

  # Other scopes may use custom stacks.
  # scope "/api", SbWebWeb do
  #   pipe_through :api
  # end
end
