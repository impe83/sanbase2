defmodule SanbaseWeb.Graphql.SanbaseDataloader do
  alias SanbaseWeb.Graphql.ClickhouseDataloader
  alias SanbaseWeb.Graphql.PriceDataloader
  alias SanbaseWeb.Graphql.ParityDataloader
  alias SanbaseWeb.Graphql.MetricPostgresDataloader

  @spec data() :: Dataloader.KV.t()
  def data() do
    Dataloader.KV.new(&query/2)
  end

  @spec query(
          :average_daily_active_addresses
          | :average_dev_activity
          | :eth_balance
          | :eth_spent
          | :volume_change_24h
          | {:price, any()}
          | :market_segment
          | :infrastructure
          | :comment_insight_id
          | :comment_timeline_event_id
          | :insights_comments_count
          | :timeline_events_comments_count
          | :project_by_slug
          | :aggregated_metric,
          any()
        ) :: {:error, String.t()} | {:ok, float()} | map()
  def query(queryable, args) do
    case queryable do
      x
      when x in [
             :average_daily_active_addresses,
             :average_dev_activity,
             :eth_spent,
             :aggregated_metric
           ] ->
        ClickhouseDataloader.query(queryable, args)

      :volume_change_24h ->
        PriceDataloader.query(queryable, args)

      {:price, _} ->
        PriceDataloader.query(queryable, args)

      :eth_balance ->
        ParityDataloader.query(queryable, args)

      x
      when x in [
             :comment_insight_id,
             :comment_timeline_event_id,
             :infrastructure,
             :market_segment,
             :insights_comments_count,
             :timeline_events_comments_count,
             :project_by_slug
           ] ->
        MetricPostgresDataloader.query(queryable, args)
    end
  end
end
