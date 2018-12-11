defmodule SB.TxInfo do
  # prev_hash is reversed on bytes while storing and reversed back while searching
  defstruct hash: nil, version: "01000000", num_inputs: 0, inputs: [], num_outputs: 0, outputs: []
  # inputs = [
  #   {
  #     prev_hash
  #     prev_out_index
  #     script_len
  #     scriptSig
  #     sequence
  #   }
  # ]

  # outputs = [
  #   {
  #     value
  #     script_len
  #     scriptPubKey
  #   }
  # ]
end
