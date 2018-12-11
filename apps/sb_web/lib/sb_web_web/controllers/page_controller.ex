defmodule SbWebWeb.PageController do
  use SbWebWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
