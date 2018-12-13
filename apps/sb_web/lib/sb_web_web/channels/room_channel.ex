defmodule SbWebWeb.RoomChannel do
  @moduledoc false
  use Phoenix.Channel

  require Logger

  def join("room:tx", _message, socket) do

    {:ok, socket}
  end

  def join("room:wallet", _message, socket) do
    {:ok, socket}
  end

  def join("room:" <> _private_room_id, _params, _socket) do
    {:error, %{reason: "unauthorized"}}
  end

  def handle_in("new_msg", %{"body" => body}, socket) do
    Logger.debug("Called with message "<> inspect body)
    broadcast!(socket, "new_msg", %{body: body})

    {:noreply, socket}
  end


end
