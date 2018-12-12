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


#    Process.sleep(5000)
#    SbWebWeb.Endpoint.broadcast!("room:tx", "new_msg", %{uid: "Hi", body: "cfc"})

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
end
