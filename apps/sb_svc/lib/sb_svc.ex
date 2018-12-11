defmodule SB do
  use Application

  require Logger

  @moduledoc """
  Documentation for SB.
  """

  def start(type, args) do
    Logger.debug("Inside start " <> inspect(__MODULE__) <> " " <> "with args: " <> inspect(args) <> "and type: " <> inspect(type))
    SB.Supervisor.start_link(args)
    #    ret_val = GenServer.call(SB.Master, {:init, args}, :infinity)
    #    Logger.debug("Inside #{inspect __MODULE__} SB.Master return val #{inspect ret_val}")
    #    ret_val
  end

end
