defmodule SbWebWeb.SBController do
  @moduledoc false

  use SbWebWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end

  def tx(conn, _params) do
    render(conn, "index.html")
  end

end
