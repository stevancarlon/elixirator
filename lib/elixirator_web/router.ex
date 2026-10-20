defmodule ElixiratorWeb.Router do
  use ElixiratorWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ElixiratorWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", ElixiratorWeb do
    pipe_through :browser

    live "/", MissionLive, :index
  end
end
