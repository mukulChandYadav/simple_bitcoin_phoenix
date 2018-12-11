defmodule SB.NodeInfo do
  @moduledoc false

  defstruct wallet: %SB.WalletInfo{}, is_miner: false, node_id: nil, block: nil, public_key: nil, secret_key: nil

end
