defmodule SB.WalletInfo do
  @moduledoc false

  defstruct wallet_pid: nil,
            owner_pid: nil,
            owner_id: nil,
            secret_key: nil,
            public_key: nil
end
