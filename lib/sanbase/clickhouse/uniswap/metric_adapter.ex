defmodule Sanbase.Clickhouse.Uniswap.MetricAdapter do
  @behaviour Sanbase.Metric.Behaviour
  import Sanbase.Utils.Transform

  @aggregations [:sum]

  @timeseries_metrics []

  @histogram_metrics ["uniswap_top_claimers"]

  @metrics @histogram_metrics ++ @timeseries_metrics

  @access_map Enum.into(@metrics, %{}, fn metric -> {metric, :restricted} end)
  @min_plan_map Enum.into(@metrics, %{}, fn metric -> {metric, :free} end)

  @free_metrics @metrics
  @restricted_metrics []

  @default_complexity_weight 0.3

  @impl Sanbase.Metric.Behaviour
  def has_incomplete_data?(_), do: false

  @impl Sanbase.Metric.Behaviour
  def complexity_weight(_), do: @default_complexity_weight

  @impl Sanbase.Metric.Behaviour
  def timeseries_data(_metric, _selector, _from, _to, _interval, _opts) do
    {:error, "Timeseries data is not implemented for uniswap metrics."}
  end

  def histogram_data("uniswap_top_claimers", %{slug: "uniswap"}, from, to, _interval, limit) do
    query = """
    SELECT
      to AS address,
      amount AS value
    FROM
    (
    SELECT
      to,
      SUM(value)/1e18 AS amount
    FROM erc20_transfers
    PREWHERE
      dt >= toDateTime(?1) AND
      dt < toDateTime(?2) AND
      from = '0x090d4613473dee047c3f2706764f49e0821d256e' AND
      contract = '0x1f9840a85d5af5bf1d1762f925bdaddc4201f984'
    GROUP BY to
    ORDER BY amount DESC
    LIMIT ?3
    ) ORDER BY value
    """

    args = [from |> DateTime.to_unix(), to |> DateTime.to_unix(), limit]

    Sanbase.ClickhouseRepo.query_transform(query, args, fn [address, value] ->
      %{address: address, value: value}
    end)
    |> maybe_apply_function(fn data -> Enum.sort_by(data, & &1.value, :desc) end)
  end

  @impl Sanbase.Metric.Behaviour
  def aggregated_timeseries_data(_metric, _selector, _from, _to, _opts) do
    {:error, "Aggregated timeseries data is not implemented for uniswap metrics."}
  end

  @impl Sanbase.Metric.Behaviour
  def slugs_by_filter(_metric, _from, _to, _operator, _threshold, _opts) do
    {:error, "Slugs filtering is not implemented for uniswap metrics."}
  end

  @impl Sanbase.Metric.Behaviour
  def slugs_order(_metric, _from, _to, _direction, _opts) do
    {:error, "Slugs ordering is not implemented for uniswap metrics."}
  end

  @impl Sanbase.Metric.Behaviour
  def first_datetime(_metric, _slug) do
    {:ok, ~U[2020-09-14 00:00:00Z]}
  end

  @impl Sanbase.Metric.Behaviour
  def last_datetime_computed_at(_metric, _slug) do
    {:ok, Timex.now()}
  end

  @impl Sanbase.Metric.Behaviour
  def metadata(metric) do
    {:ok,
     %{
       metric: metric,
       min_interval: "1h",
       default_aggregation: :sum,
       available_aggregations: @aggregations,
       available_selectors: [:slug],
       data_type: :timeseries,
       complexity_weight: @default_complexity_weight
     }}
  end

  @impl Sanbase.Metric.Behaviour
  def human_readable_name(metric) do
    case metric do
      "uniswap_top_claimers" ->
        {:ok, "Uniswap Top Claimers"}
    end
  end

  @impl Sanbase.Metric.Behaviour
  def available_aggregations(), do: @aggregations

  @impl Sanbase.Metric.Behaviour
  def available_timeseries_metrics(), do: @timeseries_metrics

  @impl Sanbase.Metric.Behaviour
  def available_histogram_metrics(), do: @histogram_metrics

  @impl Sanbase.Metric.Behaviour
  def available_metrics(), do: @metrics

  @impl Sanbase.Metric.Behaviour
  def available_metrics(%{slug: slug}) do
    case slug do
      "uniswap" -> @metrics
      _ -> []
    end
  end

  @impl Sanbase.Metric.Behaviour
  def available_slugs() do
    {:ok, ["uniswap"]}
  end

  @impl Sanbase.Metric.Behaviour
  def available_slugs(metric) when metric in @metrics do
    available_slugs()
  end

  @impl Sanbase.Metric.Behaviour
  def free_metrics(), do: @free_metrics

  @impl Sanbase.Metric.Behaviour
  def restricted_metrics(), do: @restricted_metrics

  @impl Sanbase.Metric.Behaviour
  def access_map(), do: @access_map

  @impl Sanbase.Metric.Behaviour
  def min_plan_map(), do: @min_plan_map
end
