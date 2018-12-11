defmodule SB.UtxoInfo do
  defstruct tx_id: nil, out_index: -1, value: 0, scriptPubKey: nil

  # outputs = [
  #   {
  #     value
  #     script_len
  #     scriptPubKey
  #   }
  # ]
end
