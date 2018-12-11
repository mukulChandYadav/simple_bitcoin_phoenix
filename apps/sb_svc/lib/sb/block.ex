defmodule SB.Block do
  @moduledoc false

  require Logger

  # Setting target nBits to 4, can be configured to other values
  defstruct block_header: %SB.BlockHeader{},
            timestamp: :os.system_time(:millisecond),
            target: 4,
            tx: [],
            block_id: 0,
            prev_block: nil

  defp prepare_block_header(prev_block, nonce, txs) do
    prev_hash =
      if(prev_block == nil) do
        ""
      else
        SB.BlockHeader.prepare_prev_hash(prev_block.block_header)
      end

    tx_hash =
      Enum.reduce(txs, SB.CryptoHandle.hash("initial", :sha256), fn x, acc ->
        acc <> x[:hash] <> SB.Tx.generate_tx_for_hash(x)
      end)

    %SB.BlockHeader{nonce: nonce, prev_hash: prev_hash, tx_hash: tx_hash}
  end

  def prepare_block(base_block, nonce, new_tx) do
    # Logger.debug("Inside #{inspect __MODULE__} Prepare block args - #{inspect prev_block}, #{inspect nonce}, #{inspect new_tx}")

    new_block_id = base_block.block_id + 1
    block_ts = :os.system_time(:millisecond)
    new_block = %{base_block | timestamp: block_ts}
    new_block = %{new_block | block_id: new_block_id}

    txs = List.insert_at(base_block.tx, -1, new_tx)
    new_block = %{new_block | tx: txs}

    prev_block =
      if(base_block.block_id == 0) do
        nil
      else
        base_block
      end

    block_header = prepare_block_header(prev_block, nonce, txs)
    new_block = %{new_block | block_header: block_header}

    new_block = %{new_block | prev_block: prev_block}
    new_block
  end
end
