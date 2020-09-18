defmodule Sanbase.Clickhouse.Research.Uniswap do
  alias Sanbase.ClickhouseRepo

  def value_distribution() do
    {query, args} = value_distribution_query()

    ClickhouseRepo.query_transform(query, args, fn [_, value] ->
      value
    end)
    |> case do
      {:ok, [total_minted, cex, dex, other, dex_trader]} ->
        {:ok,
         %{
           total_minted: total_minted,
           centralized_exchanges: cex,
           decentralized_exchanges: dex,
           other_transfers: other,
           dex_trader: dex_trader
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp value_distribution_query() do
    query = """
    SELECT 'total minted' as exchange_status,
    sum(value)/1e18 as token_value
    FROM erc20_transfers
    PREWHERE (contract = '0x1f9840a85d5af5bf1d1762f925bdaddc4201f984')
      AND (value = 400000000000000000000.)
      AND (from = '0x090d4613473dee047c3f2706764f49e0821d256e')
    UNION ALL
    SELECT multiIf(hasAny(labels, ['decentralized_exchange']), 'decentralized_exchange',
                hasAny(labels, ['centralized_exchange', 'deposit', 'withdrawal']), 'centralized_exchange',
                hasAny(labels, ['dex_trader']), 'dex_trader', 'other transfers' ) as exchange_status,
        sum(value_) as token_value
    FROM (
    SELECT
        from as address,
        splitByChar(',', dictGetString('default.eth_label_dict', 'labels', tuple(cityHash64(to), toUInt64(0)))) as labels,
        if(value/1e18>400, 400, value/1e18)  as value_
    FROM erc20_transfers
    GLOBAL ALL INNER JOIN (
        SELECT distinct to as address
        FROM erc20_transfers
        PREWHERE (contract = '0x1f9840a85d5af5bf1d1762f925bdaddc4201f984')
              AND (value = 400000000000000000000.)
              AND (from = '0x090d4613473dee047c3f2706764f49e0821d256e'))
    USING address
    PREWHERE contract = '0x1f9840a85d5af5bf1d1762f925bdaddc4201f984'
          AND dt >= toDateTime('2020-09-17 00:06:53')
    )
    GROUP BY exchange_status
    """

    {query, []}
  end
end