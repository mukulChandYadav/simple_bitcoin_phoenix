defmodule SB.Simulator do
  @moduledoc false

  require Logger
  use GenServer

  # Initialization
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    Logger.debug("Initializing simulator")

    state = %{}

    {:ok, state}
  end

  def start_simulation() do
    SB.Master.init_network()
    Logger.debug("Starting simulation")
    GenServer.call(__MODULE__, :start_simulation, :infinity)
  end

  def handle_call(:start_simulation, _from, state) do
    amount = 0.01
    num_tx = 2

    wallet_pid = perform_coinbase_tx()

    receivers_wallet_pid =
      SB.Master.get_wallet_pids()
      |> List.delete(wallet_pid)

    Logger.debug("Reciever pids: " <> inspect(receivers_wallet_pid))

    possible_sender_pids =
      Enum.reduce(Enum.take(receivers_wallet_pid, 8), [wallet_pid], fn receiver_wallet_pid, acc ->
        if wallet_pid != receivers_wallet_pid do
          txd_wallet_id = peform_tx(wallet_pid, receiver_wallet_pid, amount)
          acc ++ [txd_wallet_id]
        else
          acc
        end
      end)

    Logger.debug("Possible sender pids: " <> inspect(possible_sender_pids))

    Process.sleep(5000)

    sender_pids =
      Enum.reduce_while(possible_sender_pids, possible_sender_pids, fn sender_pid, acc ->
        current_sender_index =
          Enum.find_index(possible_sender_pids, fn pid -> pid == sender_pid end)

        if current_sender_index < num_tx do
          {:ok, receiver_wallet_pid} = Enum.fetch(receivers_wallet_pid, current_sender_index)

          Logger.debug(
            "Trying to send from: " <> inspect(sender_pid) <> "to" <> inspect(receiver_wallet_pid)
          )

          if(Process.alive?(sender_pid) && Process.alive?(receiver_wallet_pid)) do
            txd_wallet_id = peform_tx(sender_pid, receiver_wallet_pid, amount)
            {:cont, acc ++ [txd_wallet_id]}
          else
            {:cont, acc}
          end
        else
          {:halt, acc}
        end
      end)

    Process.sleep(40000)

    {:reply, :ok, state}
  end

  defp perform_coinbase_tx do
    amount = 1
    wallet_pid = SB.Master.perform_tranx(amount)

    # Logger.debug(
    #   "Call to get wallet state: " <> inspect(GenServer.call(wallet_pid, :get_state_info))
    # )

    wallet_state = GenServer.call(wallet_pid, :get_state_info, :infinity)

    owner_pid = wallet_state.owner_pid
    owner_state = GenServer.call(owner_pid, :get_state, :infinity)

    # Process.sleep(20000)

    block = check_for_block_in_state(owner_pid, owner_state.block.block_id, 0)
    Logger.debug("Block test after coinbase: " <> inspect(block))

    # TODO Improve assertion
    {:ok, balance} = GenServer.call(wallet_pid, :get_balance, :infinity)

    Logger.debug(
      "Amount*100000000 and balance: " <>
        inspect(amount * 100_000_000) <> "  " <> inspect(balance)
    )

    wallet_pid
  end

  def peform_tx(sender_wallet_pid, receiver_wallet_pid, amount) do
    Logger.debug("Receiver wallet pid: " <> inspect(receiver_wallet_pid))
    receiver_state = GenServer.call(receiver_wallet_pid, :get_state_info, :infinity)

    receiver_bitcoinaddr_pubkey =
      receiver_state.public_key
      |> SB.CryptoHandle.generate_address()
      |> Base.encode16()

    GenServer.call(
      sender_wallet_pid,
      {:create_transaction, amount, receiver_wallet_pid, receiver_bitcoinaddr_pubkey},
      :infinity
    )

    receiver_wallet_pid
  end

  defp check_for_block_in_state(pid, block_id, threshold_block_id)
       when block_id > threshold_block_id do
    block_id
  end

  defp check_for_block_in_state(pid, block_id, threshold_block_id) do
    Process.sleep(1000)

    state = GenServer.call(pid, :get_state, :infinity)
    Logger.debug("Block state now: " <> inspect(state))
    check_for_block_in_state(pid, state.block.block_id, threshold_block_id)
  end

  # def main do
  #   start_simulation()
  # end
end

# SB.Simulator.main()
