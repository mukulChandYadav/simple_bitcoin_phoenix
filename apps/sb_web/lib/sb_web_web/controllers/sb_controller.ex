defmodule SbWebWeb.SBController do
  @moduledoc false

  require Logger

  use SbWebWeb, :controller

  def index(conn, _params) do
    Logger.debug("Reached index endpoint")
    render(conn, "index.html")
  end

  def tx(conn, _params) do
    Logger.debug("Reached tx endpoint")
    render(conn, "index.html")
  end

  def simulate(conn, _params) do
    Logger.debug("Reached simulate endpoint")

    # Start simulation
    Task.async(SB.Master.perform_transaction())

    render(conn, "index.html")
  end

end
