defmodule SbWebWeb.RoomChannel do
  @moduledoc false
  use Phoenix.Channel

  require Logger

  def join("room:sbp_channel", _message, socket) do

    {:ok, socket}
  end

  def join("room:" <> _private_room_id, _params, _socket) do
    {:error, %{reason: "unauthorized"}}
  end

  def handle_in(topic, %{"body" => body}, socket) do
    Logger.debug("Called with message "<> inspect body)
    broadcast!(socket, topic, %{body: body})

    {:noreply, socket}
  end


end
