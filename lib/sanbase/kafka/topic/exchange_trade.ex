defmodule Sanbase.Kafka.Topic.ExchangeTrade do
  defstruct [:source, :symbol, :timestamp, :amount, :cost, :price, :side]

  @compile :inline_list_funcs
  @compile inline: [format_timestamp: 1, format_side: 1]

  @spec format_message(map()) :: map()
  def format_message(message_map) do
    message_map
    |> Enum.map(fn {k, v} -> {Regex.replace(~r/_(\d+)/, k, "\\1"), v} end)
    |> Enum.map(fn {k, v} -> {String.to_existing_atom(k), v} end)
    |> Enum.into(%{})
    |> format_timestamp()
    |> format_side()
    |> Sanbase.Utils.Transform.rename_map_keys!(
      old_keys: [:timestamp, :source, :symbol],
      new_keys: [:datetime, :exchange, :ticker_pair]
    )
  end

  defp format_timestamp(%{timestamp: timestamp} = exchange_trade) do
    %{exchange_trade | timestamp: DateTime.from_unix!(floor(timestamp), :millisecond)}
  end

  defp format_side(%{side: side} = exchange_trade) do
    %{exchange_trade | side: String.to_existing_atom(side)}
  end
end
