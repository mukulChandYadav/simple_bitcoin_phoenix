defmodule SB.Tx do
  require Logger

  def get_pid do
    self()
    |> :erlang.pid_to_list()
    |> to_string
    |> String.slice(1..-2)
  end

  def get_json(filename) do
    # Logger.debug("Looking for file: #{inspect filename}")
    with {:ok, body} <- File.read(filename), {:ok, json} <- Poison.decode(body), do: {:ok, json}
  end

  def append_json(node_id, type, path, content) when type == "utxo" do
    tx_id = content[:hash]
    output_index = content[:out_index]

    content = Map.drop(content, [:hash, :out_index])

    {:ok, json} =
      path
      |> get_json

    # Logger.debug("content: " <> inspect(content))

    case Map.has_key?(json, tx_id) do
      true ->
        {_, appended_submap} =
          Map.get_and_update!(json, tx_id, fn curr_map ->
            {curr_map, Map.put(curr_map, output_index, content)}
          end)

        appended_submap

      false ->
        out_index_map = Map.put(%{}, output_index, content)
        Map.put(json, tx_id, out_index_map)
    end
  end

  def append_json(node_id, type, path, content) when type == "keys" do
    pid = node_id

    {:ok, json} =
      path
      |> get_json

    Map.put(json, pid, content)
  end

  def append_json(_, _, path, content) do
    tx_id = content[:hash]

    {:ok, json} =
      path
      |> get_json

    Map.put(json, tx_id, content)
  end

  def write_json(node_id, type, content) when content == %{} do
    # Logger.debug("---------Content empty--------")
    # Logger.debug("Type: " <> inspect(type))

    path = Path.absname("./lib/data/")
    # Logger.debug(inspect(__MODULE__) <> "Dir path: " <> inspect(path))
    filename = inspect(node_id) <> type <> ".json"
    :ok = File.mkdir_p!(path)

    json_encoded_content =
      %{}
      |> Poison.encode!()

    File.write!(path <> "/" <> filename, json_encoded_content)
  end

  def write_json(node_id, type, content) do
    path = Path.absname("./lib/data/")
    # Logger.debug(inspect(__MODULE__) <> " Dir path: " <> inspect(path))
    filename = inspect(node_id) <> type <> ".json"
    :ok = File.mkdir_p!(path)

    # Logger.debug("---------Content not empty--------")
    # Logger.debug("Content: " <> inspect(content))
    # Logger.debug("Type: " <> inspect(type))

    json_encoded_content =
      append_json(node_id, type, path <> "/" <> filename, content)
      |> Poison.encode!()

    File.write!(path <> "/" <> filename, json_encoded_content)
  end

  defp string_slice(bc_addr, from, to) do
    String.slice(bc_addr, from..to)
  end

  def generate_signature(message, private_key) do
    Logger.debug("Pvt_key: " <> inspect(private_key))

    {:ok, private} =
      private_key
      |> Base.decode16()

    :crypto.sign(
      :ecdsa,
      :sha256,
      message,
      [private, :secp256k1]
    )
  end

  def verify_signature(message, signature, public_key) do
    {:ok, public} =
      public_key
      |> Base.decode16()

    :crypto.verify(
      :ecdsa,
      :sha256,
      message,
      signature,
      [public, :secp256k1]
    )
  end

  def generate_output_for_hash(output) do
    # tx_out = value <> pk_script_length <> pk_script
    # %{value: amount, script_len: script_len, scriptPubKey: scriptPubKey}

    value = output[:value]
    script_len = output[:script_len]
    scriptPubKey = output[:scriptPubKey]

    value <> script_len <> scriptPubKey
  end

  def generate_input_for_hash(input) do
    prev_hash = input[:prev_hash]
    prev_out_index = input[:prev_out_index]
    script_len = input[:script_len]
    scriptSig = input[:scriptSig]
    sequence = input[:sequence]

    prev_hash <> prev_out_index <> script_len <> scriptSig <> sequence
  end

  def generate_inputs(utxos) do
    sequence =
      "ffffffff"
      |> String.upcase()

    Logger.debug("UTXOS for input: " <> inspect(utxos))

    for utxo <- utxos do
      Logger.debug("Current UTXO: " <> inspect(utxo))

      outpoint_hash = Map.keys(utxo) |> List.first()
      outpoint_index = Map.keys(utxo[outpoint_hash]) |> List.first()
      signature_script = utxo[outpoint_hash][outpoint_index]["scriptPubKey"]

      # pk_script = utxo["scriptPubKey"]
      script_len =
        signature_script
        |> Binary.from_hex()
        |> byte_size()
        |> to_string()

      script_len =
        if String.length(script_len) == 1 do
          "0" <> script_len
        else
          script_len
        end

      # Logger.debug("Script len of current input's pubKeyScript: " <> inspect(script_len))

      # Logger.debug("Outpoint hash: " <> inspect(outpoint_hash))
      # Logger.debug("Outpoint index: " <> inspect(outpoint_index))
      # Logger.debug("Signature script (Placehoded by pubKeyScript)" <> inspect(signature_script))

      %{
        prev_hash: outpoint_hash,
        prev_out_index: outpoint_index,
        script_len: script_len,
        scriptSig: signature_script,
        sequence: sequence
      }
    end
  end

  def update_utxo_json(:sender, node_id, tx) do
    change_output = List.last(tx[:outputs])
    value = change_output[:value]
    scriptPubKey = change_output[:scriptPubKey]

    trans_hash = tx[:hash]
    # Map.keys(tx) |> List.first()
    Logger.debug("L0 key : " <> inspect(trans_hash))
    out_index = "00000001"

    utxo_lvl_2 =
      Map.put(%{}, :value, value)
      |> Map.put(:scriptPubKey, scriptPubKey)

    utxo_lvl_1 = Map.put(%{}, out_index, utxo_lvl_2)

    utxo = Map.put(%{}, trans_hash, utxo_lvl_1)

    # content = elem(utxo, 1)

    Logger.debug("Writing for sender: " <> inspect(utxo))
    {:ok, content} = Poison.encode(utxo)

    path = Path.absname("./lib/data/")
    Logger.debug(inspect(__MODULE__) <> " Dir path: " <> inspect(path))
    filename = inspect(node_id) <> "utxo" <> ".json"
    :ok = File.mkdir_p!(path)

    Logger.debug("File path: " <> inspect(path <> "/" <> filename))
    Logger.debug("Content: " <> inspect(content))
    File.write!(path <> "/" <> filename, content)
  end

  def update_utxo_json(:receiver, node_id, tx) do
    Logger.debug(inspect(node_id) <> "Reciever " <> inspect(tx))
    change_output = List.first(tx[:outputs])
    value = change_output[:value]

    content =
      if(value |> String.to_integer(16) != 0) do
        Logger.debug(inspect(node_id) <> " Amount is not 0: " <> inspect(tx))
        scriptPubKey = change_output[:scriptPubKey]

        trans_hash = tx[:hash]
        Map.keys(tx) |> List.first()
        out_index = "00000000"

        utxo_lvl_2 =
          Map.put(%{}, :value, value)
          |> Map.put(:scriptPubKey, scriptPubKey)

        utxo_lvl_1 = Map.put(%{}, out_index, utxo_lvl_2)

        utxo = Map.put(%{}, trans_hash, utxo_lvl_1)

        Logger.debug("Writing for reciever: " <> inspect(utxo))
        {:ok, content} = Poison.encode(utxo)
        content
      else
        {:ok, content} = Poison.encode(%{})
        content
      end

    path = Path.absname("./lib/data/")
    # Logger.debug(inspect(__MODULE__) <> " Dir path: " <> inspect(path))
    filename = inspect(node_id) <> "utxo" <> ".json"
    :ok = File.mkdir_p!(path)

    File.write!(path <> "/" <> filename, content)
  end

  def create_transaction_block(_, utxos, _, _, _, _) when utxos == [] do
    false
  end

  def create_transaction_block(node_id, utxos, receiver_bc_addr, amount, private_key, public_key) do
    Logger.debug("---------Creating Transaction-----------")

    # transaction = (version <> tx_in_count <> tx_in <> tx_out_count <> tx_out <> lock_time <> sigHash)

    transaction = ""
    version = "01000000"
    transaction = transaction <> version
    # locktime = "00000000"
    # sigHash = "01000000"
    private_key = private_key |> Base.encode16()
    public_key = public_key |> Base.encode16()

    # Get the existing balnce in the input and calculate the remaining balance after the transaction accordingly
    input_utxo = List.first(utxos)

    input_values =
      for {_, out_index_map} <- input_utxo do
        Logger.debug("out index map: " <> inspect(out_index_map))

        balance =
          Enum.reduce(out_index_map, {}, fn {k, v}, acc ->
            curr_balance =
              v["value"]
              |> String.to_integer(16)

            debit = amount
            # |> String.to_integer(16)

            scriptPubkey = v["scriptPubKey"]
            Logger.debug("scriptPubKey: " <> inspect(scriptPubkey))
            acc = Tuple.insert_at(acc, 0, scriptPubkey)
            acc = Tuple.insert_at(acc, 0, curr_balance - debit)

            acc
          end)
      end

    Logger.debug("Input values: " <> inspect(input_values))

    {remaining_balance, change_scriptPubKey} =
      input_values
      |> List.first()

    change_script_len =
      change_scriptPubKey
      |> Binary.from_hex()
      |> byte_size()
      |> to_string()

    # Creating outputs
    # outputs = [
    #   {
    #     value
    #     script_len
    #     scriptPubKey
    #   }
    # ]
    # tx_out = value <> pk_script_length <> pk_script
    outputs = []

    pub_key_hash =
      receiver_bc_addr
      |> string_slice(2, -9)

    # Logger.debug("PubKey Hash: " <> inspect(pub_key_hash))

    scriptPubKey =
      ("76a914" <> pub_key_hash <> "88ac")
      |> String.upcase()

    # Logger.debug("scriptPubKey: " <> inspect(scriptPubKey))

    script_len =
      scriptPubKey
      |> Binary.from_hex()
      |> byte_size()
      |> to_string()

    script_len =
      if String.length(script_len) == 1 do
        "0" <> script_len
      else
        script_len
      end

    # Logger.debug("script len: " <> inspect(script_len))

    amount =
      amount
      |> Integer.to_string(16)

    pad = String.duplicate("0", 16 - String.length(amount))

    amount =
      if String.length(amount) < 16 do
        pad <> amount
      else
        amount
      end

    # Logger.debug("Amount: " <> inspect(amount))

    remaining_balance = remaining_balance |> Integer.to_string(16)
    pad = String.duplicate("0", 16 - String.length(remaining_balance))

    remaining_balance =
      if String.length(remaining_balance) < 16 do
        pad <> remaining_balance
      else
        remaining_balance
      end

    outputs =
      outputs ++
        [
          %{value: amount, script_len: script_len, scriptPubKey: scriptPubKey}
        ] ++
        [
          %{
            value: remaining_balance,
            script_len: change_script_len,
            scriptPubKey: change_scriptPubKey
          }
        ]

    Logger.debug("---> Outputs: " <> inspect(outputs))

    tx_out = amount <> script_len <> scriptPubKey
    # Logger.debug("TX_OUT: " <> inspect(tx_out))

    num_outputs =
      length(outputs)
      |> Integer.to_string(16)

    num_outputs =
      if String.length(num_outputs) == 1 do
        "0" <> num_outputs
      else
        num_outputs
      end

    # Logger.debug("Number of outputs: " <> inspect(num_outputs))

    # Creating inputs
    # inputs = [
    #   {
    #     prev_hash
    #     prev_out_index
    #     script_len
    #     scriptSig
    #     sequence
    #   }
    # ]
    # tx_in = previous_output <> script_length <> signature_script <> sequence
    # previous_output = outpoint_hash <> outPoint_index

    # sequence ="ffffffff"|> String.upcase()

    inputs =
      utxos
      |> generate_inputs()

    # inputs_for_hash =
    #   inputs_with_hash
    #   |> Enum.map(fn input -> input[:input_for_hash] end)

    # inputs =
    #   inputs_with_hash
    #   |> Enum.map(fn input -> Map.delete(input, :input_for_hash) end)

    # Logger.debug("Inputs: " <> inspect(inputs))

    # Enum.each(utxos, fn utxo ->
    #   nil
    # end)

    num_inputs =
      length(utxos)
      |> Integer.to_string(16)

    num_inputs =
      if String.length(num_inputs) == 1 do
        "0" <> num_inputs
      else
        num_inputs
      end

    # Logger.debug("Number of inputs: " <> inspect(num_inputs))

    transaction = transaction <> num_inputs
    # Logger.debug("Transaction + num_inputs: " <> inspect(transaction))

    # Evaluating ScriptSig for each input

    # transaction = (version <> tx_in_count <> tx_in <> tx_out_count <> tx_out <> lock_time <> sigHash)

    path = Path.absname("./lib/data/") <> node_id <> "keys.json"

    # {:ok, keys_map} =
    #   path
    #   |> get_json

    # Logger.debug("Keys map: " <> inspect(keys_map))

    pid = node_id
    # #Logger.debug("Finding Pvt key for pid iter: " <> inspect(pid))
    # private_key = keys_map[pid]["private_key"]
    # #Logger.debug("Pvt key in iter: " <> inspect(private_key))

    # public_key = keys_map[pid]["public_key"]
    # #Logger.debug("Pub key in iter: " <> inspect(public_key))

    scriptSigs =
      for iter <- 0..(length(inputs) - 1) do
        input = Enum.fetch(inputs, iter)

        {:ok, input} =
          case input do
            {:ok, _} ->
              input

            {:error} ->
              # Logger.debug("Eror in fetching the input")
              {:error, "No such input"}
          end

        # #Logger.debug("Input in iteration: " <> inspect(input))

        # input_index = Enum.find_index(inputs, fn ip -> input == ip end)
        # #Logger.debug("Input index: " <> inspect(input_index))

        input_for_hash =
          input
          |> generate_input_for_hash()

        Logger.debug("Input for hash in iteration: " <> inspect(input_for_hash))

        {:ok, binary_transaction} =
          (version <> num_inputs <> input_for_hash <> num_outputs <> tx_out)
          |> Base.decode16()

        # <> locktime <> sigHash)
        # #Logger.debug("Binary tx in iter: " <> inspect(binary_transaction |> byte_size()))

        signature =
          binary_transaction
          |> SB.CryptoHandle.hash(:sha256)
          |> SB.CryptoHandle.hash(:sha256)
          |> Base.encode16(case: :upper)
          |> generate_signature(private_key)

        # |> Base.encode16()

        # # For signature veriifcation
        # binary_transaction
        # |> SB.CryptoHandle.hash(:sha256)
        # |> SB.CryptoHandle.hash(:sha256)
        # |> Base.encode16(case: :upper)
        # |> verify_signature(signature, public_key)
        # |> IO.inspect()

        sig_length =
          signature
          |> byte_size()
          |> Integer.to_string(16)

        signature =
          signature
          |> Base.encode16()

        # Logger.debug("Signature: " <> inspect(signature))
        sig_length <> signature <> public_key
      end

    # Logger.debug("scriptSigs: " <> inspect(scriptSigs))

    # Inserting scriptsig in each of the inputs

    inputs =
      for input <- inputs do
        scriptSig_index = Enum.find_index(inputs, fn ip -> input == ip end)
        # Logger.debug("scriptSig Index : " <> inspect(scriptSig_index))
        scriptSig = Enum.fetch(scriptSigs, scriptSig_index)

        {:ok, scriptSig} =
          case scriptSig do
            {:ok, _} ->
              scriptSig

            {:error} ->
              # Logger.debug("Eror fetching the scriptSig")
              {:error, "No such scriptSig"}
          end

        Map.replace(input, :scriptSig, scriptSig)
      end

    # Logger.debug("Inputs after replacing with original scriptSig: " <> inspect(inputs))

    tx = %{
      version: version,
      num_inputs: num_inputs,
      inputs: inputs,
      num_outputs: num_outputs,
      outputs: outputs
    }

    tx_hash =
      tx
      |> generate_tx_for_hash()
      |> Binary.from_hex()
      |> SB.CryptoHandle.hash(:sha256)
      |> SB.CryptoHandle.hash(:sha256)
      |> Base.encode16()

    Logger.debug("Create_tx block: " <> inspect(Map.put(tx, :hash, tx_hash)))
    Map.put(tx, :hash, tx_hash)
  end

  def generate_tx_for_hash(tx) do
    # transaction = (version <> tx_in_count <> tx_in <> tx_out_count <> tx_out <> lock_time <> sigHash)

    inputs_for_hash =
      Enum.reduce(tx[:inputs], "", fn input, acc -> acc <> generate_input_for_hash(input) end)

    # Logger.debug("Ip TX String: " <> inspect(inputs_for_hash))

    outputs_for_hash =
      Enum.reduce(tx[:outputs], "", fn output, acc -> acc <> generate_output_for_hash(output) end)

    # Logger.debug("Op TX String: " <> inspect(outputs_for_hash))
    tx[:version] <> tx[:num_inputs] <> inputs_for_hash <> tx[:num_outputs] <> outputs_for_hash
  end

  def coinbase_transaction(amt_in_satoshis, public_key) do
    # version 1, uint32_t
    version = "01000000"

    # 1 input transaction, var_int
    tx_in_count = "01"

    # the default for generation transactions since there is no transaction to use as output
    outpoint_hash = "0000000000000000000000000000000000000000000000000000000000000000"

    # also default for generation transactions, uint32_t
    outPoint_index = "ffffffff"

    previous_output = outpoint_hash <> outPoint_index

    # 77, var_int
    script_length = "4d"

    # The coinbase. In a regular transaction this would be the scriptSig, but unused in generation transactions.
    # Satoshi inserted the headline of The Times to prove that mining did not start before Jan 3, 2009.
    # ???????EThe Times 03/Jan/2009 Chancellor on brink of second bailout for banks
    signature_script =
      "04ffff001d0104455468652054696d65732030332f4a616e2f32303039204368616e63656c6c6f72206f6e206272696e6b206f66207365636f6e64206261696c6f757420666f722062616e6b73"

    # final sequence, means it can't be replaced and is immediately locked, uint32_t
    sequence = "ffffffff"

    tx_in = previous_output <> script_length <> signature_script <> sequence

    # 1 transaction output, var_int
    tx_out_count = "01"

    # 5000000000 satoshis == 50 bitcoin, uint64_t
    # 5_000_000_000
    value =
      amt_in_satoshis
      |> Integer.to_string(16)

    num_bytes = 8
    pad = 2 * num_bytes - String.length(value)

    value = String.duplicate("0", pad) <> value

    # The scriptPubKey saying where the coins are going.
    # private_key = SB.CryptoHandle.generate_private_key()

    # public_key = btc_addr_hash
    # private_key
    # |> SB.CryptoHandle.generate_public_key()

    pub_key_hash =
      public_key
      |> SB.CryptoHandle.generate_public_hash_hex()

    #      |> SB.CryptoHandle.generate_address()

    # Logger.debug("pk_hash: " <> inspect(pub_key_hash))

    pk_script = "76A914" <> pub_key_hash <> "88AC"

    # Logger.debug("pk_script_: " <> inspect(pk_script))

    # "4104678afdb0fe5548271967f1a67130b7105cd6a828e03909a67962e0ea1f61deb649f6bc3f4cef38c4f35504e51ec112de5c384df7ba0b8d578a4c702b6bf11d5fac"

    pk_script_length =
      pk_script
      |> Binary.from_hex()
      |> byte_size()
      |> to_string()

    # |> Integer.parse(16)
    # |> elem(0)

    # |> byte_size

    # Logger.debug("pk_script_length: " <> inspect(pk_script_length))

    # We can decode this.
    # 41 push the next 65 bytes onto the stack
    # 04678afdb0fe5548271967f1a67130b7105cd6a828e03909a67962e0ea1f61deb649f6bc3f4cef38c4f35504e51ec112de5c384df7ba0b8d578a4c702b6bf11d5f the 65 bytes that get pushed onto the stack
    # ac OP_CHECKSIG
    # This is a pay-to-pubkey output, which is the default for generation transactions.

    tx_out = value <> pk_script_length <> pk_script

    # immediately locked, uint32_t
    # lock_time = "00000000"

    # (version <> tx_in_count <> tx_in <> tx_out_count <> tx_out <> lock_time)
    transaction =
      (version <> tx_in_count <> tx_in <> tx_out_count <> tx_out)
      |> Binary.from_hex()

    # lock_time
    # Logger.debug("Transaction: " <> inspect(transaction |> Base.encode16()))
    # #Logger.debug("Transaction: " <> inspect(transaction |> Base.encode16()))

    trans_hash =
      transaction
      |> SB.CryptoHandle.hash(:sha256)
      |> SB.CryptoHandle.hash(:sha256)
      |> Base.encode16()

    # write_json("keys", %{
    #   private_key: private_key |> Base.encode16(),
    #   public_key: public_key |> Base.encode16()
    # })

    # Tx content
    # hash: nil, version: "01000000", num_inputs: 0, inputs: [], num_outputs: 0, outputs: []

    %{
      hash: trans_hash,
      version: version,
      num_inputs: tx_in_count,
      inputs: [],
      num_outputs: tx_out_count,
      outputs: [
        %{
          value: value,
          script_len: pk_script_length,
          scriptPubKey: pk_script
        }
      ]
    }
  end

  #   def main do
  #     write_json("tx", %{})
  #     write_json("utxo", %{})
  #     write_json("keys", %{})
  #     content = coinbase_transaction()
  #     #Logger.debug("Content: " <> inspect(content))

  #     write_json("tx", content)

  #     # Testing utxo
  #     op = Enum.at(content[:outputs], 0)

  #     utxo_content =
  #       Map.put(%{}, :hash, content[:hash])
  #       |> Map.put(:out_index, "00000000")
  #       |> Map.put(:value, op[:value])
  #       |> Map.put(:scriptPubKey, op[:scriptPubKey])

  #     write_json("utxo", utxo_content)

  #     [
  #       %{
  #         hash: content[:hash],
  #         out_index: "00000000",
  #         value: op[:value],
  #         scriptPubKey: op[:scriptPubKey]
  #       }
  #     ]
  #     |> create_transaction_block("aaaaaaaaaaaaaa", 10)
  #     |> IO.inspect()
  #   end
end

# SB.Tx.main()
# |> IO.inspect()

IO.inspect("Main executed")
