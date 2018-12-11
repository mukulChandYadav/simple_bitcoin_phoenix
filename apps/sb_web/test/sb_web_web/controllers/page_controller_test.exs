defmodule SbWebWeb.PageControllerTest do
  use SbWebWeb.ConnCase

  require Logger
  test "GET /", %{conn: conn} do
    #Logger.debug("Hello world!")
    conn = get(conn, "/")
    assert html_response(conn, 200) =~ "Welcome to Phoenix!"
  end
end
