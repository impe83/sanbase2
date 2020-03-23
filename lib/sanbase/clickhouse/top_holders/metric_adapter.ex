defmodule Sanbase.Clickhouse.TopHolders.MetricAdapter do
  @behaviour Sanbase.Metric.Behaviour

  @moduledoc ~s"""
  Uses ClickHouse to calculate the percent supply in exchanges, non exchanges and combined
  """

  import Sanbase.Clickhouse.TopHolders.SqlQuery
  import Sanbase.Utils.Transform, only: [maybe_unwrap_ok_value: 1]

  alias Sanbase.Model.Project

  require Sanbase.ClickhouseRepo, as: ClickhouseRepo

  @supported_chains_infrastrucutres ["EOS", "ETH", "BNB", "BEP2"]
  @infrastructure_to_table %{
    "EOS" => "eos_top_holders",
    "ETH" => "eth_top_holders",
    "BNB" => "bnb_top_holders",
    "BEP2" => "bnb_top_holders"
  }

  @aggregations Sanbase.Metric.SqlQuery.Helper.aggregations()

  @timeseries_metrics ["top_holders_balance"]
  @histogram_metrics []

  @metrics @histogram_metrics ++ @timeseries_metrics

  @access_map Enum.into(@metrics, %{}, fn metric -> {metric, :restricted} end)
  @min_plan_map Enum.into(@metrics, %{}, fn metric -> {metric, :free} end)

  @free_metrics Enum.filter(@access_map, fn {_, level} -> level == :free end) |> Keyword.keys()
  @restricted_metrics Enum.filter(@access_map, fn {_, level} -> level == :restricted end)
                      |> Keyword.keys()

  @default_holders_count 10

  @impl Sanbase.Metric.Behaviour
  def timeseries_data(
        metric,
        %{slug: slug} = selector,
        from,
        to,
        interval,
        aggregation
      ) do
    aggregation = aggregation || :last
    count = Map.get(selector, :holders_count, @default_holders_count)

    with {:ok, contract, decimals, infr} <- Project.contract_info_infrastructure_by_slug(slug) do
      table = Map.get(@infrastructure_to_table, infr)

      {query, args} =
        timeseries_data_query(
          table,
          metric,
          contract,
          count,
          from,
          to,
          interval,
          decimals,
          aggregation
        )

      ClickhouseRepo.query_transform(query, args, fn [timestamp, value] ->
        %{datetime: DateTime.from_unix!(timestamp), value: value}
      end)
    end
  end

  @impl Sanbase.Metric.Behaviour
  def aggregated_timeseries_data(_, %{slug: _slug}, _from, _to, _aggregation) do
    {:error, "not_implemented"}
  end

  @impl Sanbase.Metric.Behaviour
  def metadata(metric) do
    data_type =
      cond do
        metric in @timeseries_metrics -> :timeseries
        metric in @histogram_metrics -> :histogram
      end

    {:ok,
     %{
       metric: metric,
       min_interval: "1d",
       default_aggregation: :last,
       available_aggregations: @aggregations,
       available_selectors: [:slug, :holders_count],
       data_type: data_type
     }}
  end

  @impl Sanbase.Metric.Behaviour
  def human_readable_name(metric) do
    case metric do
      "top_holders_balance" -> {:ok, "Top Holders Balance"}
    end
  end

  @impl Sanbase.Metric.Behaviour
  def has_incomplete_data?(_), do: false

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
    with {:ok, project} <- Project.by_slug(slug),
         %{code: infr} <- Project.infrastructure(project) do
      if infr in @supported_chains_infrastrucutres do
        {:ok, @metrics}
      else
        {:ok, []}
      end
    end
  end

  @impl Sanbase.Metric.Behaviour
  def first_datetime(_metric, %{slug: slug}) do
    with {:ok, contract, _decimals, infr} <- Project.contract_info_infrastructure_by_slug(slug) do
      table = Map.get(@infrastructure_to_table, infr)
      {query, args} = first_datetime_query(table, contract)

      ClickhouseRepo.query_transform(query, args, fn [timestamp] ->
        DateTime.from_unix!(timestamp)
      end)
      |> maybe_unwrap_ok_value()
    end
  end

  @impl Sanbase.Metric.Behaviour
  def last_datetime_computed_at(_metric, %{slug: slug}) do
    with {:ok, contract, _decimals, infr} <- Project.contract_info_infrastructure_by_slug(slug) do
      table = Map.get(@infrastructure_to_table, infr)
      {query, args} = last_datetime_computed_at_query(table, contract)

      ClickhouseRepo.query_transform(query, args, fn [timestamp] ->
        DateTime.from_unix!(timestamp)
      end)
      |> maybe_unwrap_ok_value()
    end
  end

  @impl Sanbase.Metric.Behaviour
  def available_slugs() do
    Sanbase.Cache.get_or_store({:slugs_with_prices, 1800}, fn ->
      result =
        Project.List.projects()
        |> Enum.filter(&(Project.infrastructure(&1) in @supported_chains_infrastrucutres))

      {:ok, result}
    end)
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
