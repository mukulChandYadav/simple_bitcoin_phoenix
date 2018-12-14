defmodule SBTest do
  use ExUnit.Case
  doctest SB

  require Logger
  use ExUnit.Case, async: true

  setup do
    Logger.debug("Inside test setup ")
  end

  @tag timeout: 100_000_000
  test "start network and perform coinbase tx followed by a regular transaction" do
    Logger.debug("Block state now: ")
    perform_test()
    perform_coinbase_tx_test()
  end

  defp perform_test() do
    SB.Master.init_network()
    # Process.sleep(5000)
    assert true
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

  defp perform_coinbase_tx_test() do
    # Process.sleep(1000_000)
    # SB.Master.wait_till_genesis_coins_mined()

    amount = 0.1
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

    # Process.sleep(10000)
    # Get the list of wallet pids and create a transaction for one of those wallets
    receivers_wallet_pid =
      SB.Master.get_wallet_pids()
      |> List.delete(wallet_pid)

    receiver_wallet_pid =
      receivers_wallet_pid
      |> List.first()

    Logger.debug("Receiver wallet pid: " <> inspect(receiver_wallet_pid))
    receiver_state = GenServer.call(receiver_wallet_pid, :get_state_info, :infinity)

    receiver_bitcoinaddr_pubkey =
      receiver_state.public_key
      |> SB.CryptoHandle.generate_address()
      |> Base.encode16()

    response =
      GenServer.call(
        wallet_pid,
        {:create_transaction, amount * 0.01, receiver_wallet_pid, receiver_bitcoinaddr_pubkey},
        :infinity
      )

    Logger.debug("Response to create_tx 1: " <> inspect(response))
    # block = check_for_block_in_state(owner_pid, owner_state.block.block_id, 1)
    Logger.debug("Block test after coinbase: " <> inspect(block))

    # 2nd tx
    # wallet_pid = receiver_wallet_pid

    receiver_wallet_pid =
      receivers_wallet_pid
      |> List.last()

    Logger.debug("Receiver wallet pid for 2nd tx: " <> inspect(receiver_wallet_pid))

    receiver_state = GenServer.call(receiver_wallet_pid, :get_state_info, :infinity)

    receiver_bitcoinaddr_pubkey =
      receiver_state.public_key
      |> SB.CryptoHandle.generate_address()
      |> Base.encode16()

    response =
      GenServer.call(
        wallet_pid,
        {:create_transaction, amount * 0.01, receiver_wallet_pid, receiver_bitcoinaddr_pubkey},
        :infinity
      )

    Logger.debug("Response to create_tx 2: " <> inspect(response))
    # Helper.print_out_non_empty()

    # 3rd tx
    wallet_pid = receiver_wallet_pid

    receiver_wallet_pid =
      receivers_wallet_pid
      |> List.last()

    Logger.debug("Receiver wallet pid for 2nd tx: " <> inspect(receiver_wallet_pid))

    receiver_state = GenServer.call(receiver_wallet_pid, :get_state_info, :infinity)

    receiver_bitcoinaddr_pubkey =
      receiver_state.public_key
      |> SB.CryptoHandle.generate_address()
      |> Base.encode16()

    response =
      GenServer.call(
        wallet_pid,
        {:create_transaction, amount * 0.01, receiver_wallet_pid, receiver_bitcoinaddr_pubkey},
        :infinity
      )

    Process.sleep(15000)
    assert balance == amount * 100_000_000 && block != nil
  end
end
