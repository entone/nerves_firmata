defmodule Firmata.Protocol.Sysex do
  use Firmata.Protocol.Mixin

  require Logger

  def parse(<<@start_sysex>><><<command>><>sysex) do
    parse(command, sysex)
  end

  def parse(@firmware_query, sysex) do
    {:firmware_name, firmware_query(sysex)}
  end

  def parse(@capability_response, sysex) do
    {:capability_response, capability_response(sysex)[:pins]}
  end

  def parse(@analog_mapping_response, sysex) do
    {:analog_mapping_response, analog_mapping_response(sysex)}
  end

  def parse(@i2c_response, sysex) do
    {:i2c_response, binary( unmarshal(sysex))}
  end

  def parse(@string_data, sysex) do
    {:string_data, binary(unmarshal(sysex))}
  end

  def parse(bad_byte, sysex) do
    IO.puts bad_byte
    IO.puts sysex
  end

  def firmware_query(sysex) do
    sysex
    |> Enum.filter(fn(<<b>>)-> b in 32..126 end)
    |> Enum.join()
  end

  defp build_modes_array(supported_modes) do
    Enum.reduce(@modes, [], fn(mode, modes) ->
      case (supported_modes &&& (1 <<< mode)) do
        0 -> modes
        _ -> [ mode | modes]
      end
    end)
  end

  def capability_response(<<byte>>, state) do
    cond do
      byte === 127 ->
        modes_array = state[:supported_modes]
                      |> build_modes_array()
        pin = [
          supported_modes: modes_array,
          mode: @unknown
        ]
        state
        |> Keyword.put(:pins, [ pin | state[:pins] ])
        |> Keyword.put(:supported_modes, 0)
        |> Keyword.put(:n, 0)
      state[:n] === 0 ->
        supported_modes = state[:supported_modes] ||| (1 <<< byte);
        state
        |> Keyword.put(:supported_modes, supported_modes)
        |> Keyword.put(:n, state[:n] ^^^ 1)
      true ->
        Keyword.put(state, :n, state[:n] ^^^ 1)
    end
  end

  def capability_response(sysex) do
    state = [supported_modes: 0, n: 0, pins: []]
    sysex |> Enum.reduce(state, &capability_response/2)
  end

  def analog_mapping_response(<<127>>) do
    [value: nil, report: 0]
  end

  def analog_mapping_response(<<channel>>) do
    [value: nil, analog_channel: channel, report: 0]
  end

  def analog_mapping_response(sysex) do
    sysex |> Enum.map(&analog_mapping_response/1)
  end

  def binary(sysex) do
    [value: sysex]
  end

  def unmarshal(x) do
    Logger.debug("unmarshaling #{inspect x}")
    unmarshal(x, [])
  end

  def unmarshal(<<lsb, msb, rest::binary >>, acc) do
      b = <<(msb<<<7) ||| lsb>>
      unmarshal(rest, [b|acc])
  end
  def unmarshal(<< >>, acc) do
    Enum.reverse(acc) |> Enum.join
  end
end
