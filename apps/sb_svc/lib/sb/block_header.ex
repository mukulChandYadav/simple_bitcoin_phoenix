defmodule SB.BlockHeader do
  @moduledoc false

  defstruct nonce: 0, prev_hash: nil, tx_hash: nil

  def prepare_prev_hash(block_header) do
    SB.CryptoHandle.hash(inspect(block_header), :sha256)
  end

end
