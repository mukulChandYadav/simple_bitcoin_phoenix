defmodule SB.Master do
  @moduledoc false

  use GenServer

  require Logger

  def start_link(opts) do
    Logger.debug("Start_link with opts - #{inspect(opts)}")
    return_val = GenServer.start_link(__MODULE__, :ok, opts)

    Logger.debug("GenServer start return val #{inspect(return_val)}")

    return_val
  end

  def init(opts) do
    Logger.debug("Init with opts - #{inspect(opts)}")
    # send(self, :init)
    miners_table = :ets.new(:ets_miners, [:public, :set, :named_table])
    trans_table = :ets.new(:ets_trans_repo, [:public, :set, :named_table])
    mine_job_table = :ets.new(:ets_mine_jobs, [:public, :set, :named_table])
    wallet_address_table = :ets.new(:ets_wallet_addrs, [:public, :set, :named_table])

    path = Path.absname("./lib/data/")
    Logger.debug("Dir path: " <> inspect(path))

    # Delete and recreate the data folder to remove all the files
    path = Path.absname("./lib/data")
    File.rm_rf(path)
    File.mkdir_p(path)


    {:ok, %{}}
  end

  def handle_info(:init, _from, state) do
    Logger.debug("Init")
    init_network()

    {:reply, :ok, state}
  end

  def handle_call(_msg, _from, state) do
    {:reply, :ok, state}
  end

  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  def init_network() do
    Logger.debug("Init network")

    # 8
    num_miners = 10

    for x <- 1..num_miners do
      {:ok, node_pid} =
        DynamicSupervisor.start_child(SB.NodeSupervisor, {SB.Node, %{is_miner: true, node_id: x}})

      Logger.debug("Miner - #{inspect(node_pid)}")
      send(node_pid, {:mine, nil})
    end
  end

  def wait_till_genesis_coins_mined() do
    pid_list =
      :ets.foldl(
        fn {hash, w_pid}, wallet_pid_list -> List.insert_at(wallet_pid_list, -1, w_pid) end,
        [],
        :ets_wallet_addrs
      )

    num_wallets_above_threshold = Enum.reduce(pid_list, 0, &SB.Master.acc_wallet_threshold/2)

    if(num_wallets_above_threshold < length(pid_list)) do
      Process.sleep(1000)
      wait_till_genesis_coins_mined()
    end
  end

  def acc_wallet_threshold(w_pid, acc) do
    bal = GenServer.call(w_pid, :get_balance, :infinity)

    if(bal > 300_000_000) do
      acc + 1
    else
      acc
    end
  end

  def get_wallet_pids do
    :ets.foldl(
      fn {hash, w_pid}, wallet_pid_list -> List.insert_at(wallet_pid_list, -1, w_pid) end,
      [],
      :ets_wallet_addrs
    )
  end

  def perform_tranx(amount) do
    first_key = :ets.first(:ets_wallet_addrs)
    [{_, w_pid}] = :ets.lookup(:ets_wallet_addrs, first_key)
    # wallet_state = GenServer.call(w_pid, :get_state_info)

    Logger.debug("Perform tx called and calling coinbase with args: " <> inspect(w_pid))
    GenServer.call(w_pid, {:create_coinbase_transaction, amount}, :infinity)
    w_pid
  end





  ############## Remove everything below (Copied from test)


  def perform_transaction do
    Logger.debug("Block state now: " )
    perform_test()
    perform_coinbase_tx_test()
  end

  defp perform_test() do
    SB.Master.init_network()
    # Process.sleep(5000)
    #assert true
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

#    block = check_for_block_in_state(owner_pid, owner_state.block.block_id, 1)
#    Logger.debug("Block test after coinbase: " <> inspect(block))

    receiver_wallet_pid =
      receivers_wallet_pid
      |> List.last()

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

    #Helper.print_out_non_empty()

    #assert balance == amount * 100_000_000 && block != nil
  end

end
