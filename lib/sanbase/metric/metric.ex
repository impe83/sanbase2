defmodule Sanbase.Metric do
  @moduledoc """
  Dispatch module used for fetching metrics.

  This module dispatches the fetching to modules implementing the
  `Sanbase.Metric.Behaviour` behaviour. Such modules are added to the
  @metric_modules list and everything else happens automatically.
  """

  alias Sanbase.Clickhouse

  @metric_modules [
    Clickhouse.Github.MetricAdapter,
    Clickhouse.Metric,
    Sanbase.SocialData.MetricAdapter
  ]

  Module.register_attribute(__MODULE__, :available_aggregations_acc, accumulate: true)
  Module.register_attribute(__MODULE__, :free_metrics_acc, accumulate: true)
  Module.register_attribute(__MODULE__, :restricted_metrics_acc, accumulate: true)
  Module.register_attribute(__MODULE__, :access_map_acc, accumulate: true)
  Module.register_attribute(__MODULE__, :timeseries_metric_module_mapping_acc, accumulate: true)
  Module.register_attribute(__MODULE__, :histogram_metric_module_mapping_acc, accumulate: true)

  for module <- @metric_modules do
    @available_aggregations_acc module.available_aggregations()
    @free_metrics_acc module.free_metrics()
    @restricted_metrics_acc module.restricted_metrics()
    @access_map_acc module.access_map()
    @timeseries_metric_module_mapping_acc Enum.map(
                                            module.available_timeseries_metrics(),
                                            fn metric -> %{metric: metric, module: module} end
                                          )

    @histogram_metric_module_mapping_acc Enum.map(
                                           module.available_histogram_metrics(),
                                           fn metric -> %{metric: metric, module: module} end
                                         )
  end

  @available_aggregations List.flatten(@available_aggregations_acc) |> Enum.uniq()
  @free_metrics List.flatten(@free_metrics_acc) |> Enum.uniq()
  @restricted_metrics List.flatten(@restricted_metrics_acc) |> Enum.uniq()
  @timeseries_metric_module_mapping List.flatten(@timeseries_metric_module_mapping_acc)
                                    |> Enum.uniq()

  @histogram_metric_module_mapping List.flatten(@histogram_metric_module_mapping_acc)
                                   |> Enum.uniq()

  @metric_module_mapping (@histogram_metric_module_mapping ++ @timeseries_metric_module_mapping)
                         |> Enum.uniq()

  @access_map Enum.reduce(@access_map_acc, %{}, fn map, acc -> Map.merge(map, acc) end)
  @aggregation_arg_supported [nil] ++ @available_aggregations

  @metrics Enum.map(@metric_module_mapping, & &1.metric)
  @timeseries_metrics Enum.map(@timeseries_metric_module_mapping, & &1.metric)
  @histogram_metrics Enum.map(@histogram_metric_module_mapping, & &1.metric)

  @metrics_mapset MapSet.new(@metrics)
  @timeseries_metrics_mapset MapSet.new(@timeseries_metrics)
  @histogram_metrics_mapset MapSet.new(@histogram_metrics)

  def has_metric?(metric) do
    case metric in @metrics_mapset do
      true -> true
      false -> metric_not_available_error(metric)
    end
  end

  @doc ~s"""
  Get a given metric for an identifier and time range. The metric's aggregation
  function can be changed by the last optional parameter. The available
  aggregations are #{inspect(@available_aggregations)}. If no aggregation is provided,
  a default one (based on the metric) will be used.
  """
  def timeseries_data(metric, identifier, from, to, interval, aggregation \\ nil)

  def timeseries_data(_, _, _, _, _, aggregation)
      when aggregation not in @aggregation_arg_supported do
    {:error, "The aggregation '#{inspect(aggregation)}' is not supported"}
  end

  for %{metric: metric, module: module} <- @timeseries_metric_module_mapping do
    def timeseries_data(unquote(metric), identifier, from, to, interval, aggregation) do
      unquote(module).timeseries_data(
        unquote(metric),
        identifier,
        from,
        to,
        interval,
        aggregation
      )
    end
  end

  def timeseries_data(metric, _, _, _, _, _),
    do: metric_not_available_error(metric, type: :timeseries)

  @doc ~s"""
  Get the aggregated value for a metric, an identifier and time range.
  The metric's aggregation function can be changed by the last optional parameter.
  The available aggregations are #{inspect(@available_aggregations)}. If no aggregation is
  provided, a default one (based on the metric) will be used.
  """
  def aggregated_timeseries_data(metric, identifier, from, to, aggregation \\ nil)

  for %{metric: metric, module: module} <- @timeseries_metric_module_mapping do
    def aggregated_timeseries_data(unquote(metric), identifier, from, to, aggregation) do
      unquote(module).aggregated_timeseries_data(
        unquote(metric),
        identifier,
        from,
        to,
        aggregation
      )
    end
  end

  def aggregated_timeseries_data(metric, _, _, _, _),
    do: metric_not_available_error(metric, type: :timeseries)

  @doc ~s"""
  Get a histogram for a given metric
  """
  def histogram_data(metric, identifier, from, to, interval, limit \\ 100)

  for %{metric: metric, module: module} <- @histogram_metric_module_mapping do
    def histogram_data(unquote(metric), identifier, from, to, interval, limit) do
      unquote(module).histogram_data(
        unquote(metric),
        identifier,
        from,
        to,
        interval,
        limit
      )
    end
  end

  def histogram_data(metric, _, _, _, _, _),
    do: metric_not_available_error(metric, type: :histogram)

  @doc ~s"""
  Get the human readable name representation of a given metric
  """
  def human_readable_name(metric)

  for %{metric: metric, module: module} <- @metric_module_mapping do
    def human_readable_name(unquote(metric)) do
      unquote(module).human_readable_name(unquote(metric))
    end
  end

  def human_readable_name(metric), do: metric_not_available_error(metric)

  @doc ~s"""
  Get metadata for a given metric. This includes:
  - The minimal interval for which the metric is available
    (every 5 minutes, once a day, etc.)
  - The default aggregation applied if none is provided
  - The available aggregations for the metric
  - The available slugs for the metric
  """
  def metadata(metric)

  for %{metric: metric, module: module} <- @metric_module_mapping do
    def metadata(unquote(metric)) do
      unquote(module).metadata(unquote(metric))
    end
  end

  def metadata(metric), do: metric_not_available_error(metric)

  @doc ~s"""
  Get the first datetime for which a given metric is available for a given slug
  """
  def first_datetime(metric, slug)

  for %{metric: metric, module: module} <- @metric_module_mapping do
    def first_datetime(unquote(metric), slug) do
      unquote(module).first_datetime(unquote(metric), slug)
    end
  end

  def first_datetime(metric, _), do: metric_not_available_error(metric)

  @doc ~s"""
  Get all available slugs for a given metric
  """
  def available_slugs(metric)

  for %{metric: metric, module: module} <- @metric_module_mapping do
    def available_slugs(unquote(metric)) do
      unquote(module).available_slugs(unquote(metric))
    end
  end

  def available_slugs(metric), do: metric_not_available_error(metric)

  @doc ~s"""
  Get all available aggregations
  """
  def available_aggregations(), do: @available_aggregations

  @doc ~s"""
  Get all available metrics
  """
  def available_metrics(), do: @metrics

  def available_timeseries_metrics(), do: @timeseries_metrics

  def available_histogram_metrics(), do: @histogram_metrics

  @doc ~s"""
  Get all slugs for which at least one of the metrics is available
  """
  def available_slugs() do
    # Providing a 2 element tuple `{any, integer}` will use that second element
    # as TTL for the cache key
    Sanbase.Cache.get_or_store({:metric_available_slugs_all_metrics, 1800}, fn ->
      {slugs, errors} =
        Enum.reduce(@metric_modules, {[], []}, fn module, {slugs_acc, errors} ->
          case module.available_slugs() do
            {:ok, slugs} -> {slugs ++ slugs_acc, errors}
            {:error, error} -> {slugs_acc, [error | errors]}
          end
        end)

      case errors do
        [] -> {:ok, slugs |> Enum.uniq()}
        _ -> {:error, "Cannot fetch all available slugs. Errors: #{inspect(errors)}"}
      end
    end)
  end

  def available_slugs_mapset() do
    case available_slugs() do
      {:ok, list} -> {:ok, MapSet.new(list)}
      {:error, error} -> {:error, error}
    end
  end

  @doc ~s"""
  Get all free metrics
  """
  def free_metrics(), do: @free_metrics

  @doc ~s"""
  Get all restricted metrics
  """
  def restricted_metrics(), do: @restricted_metrics

  @doc ~s"""
  Get a map where the key is a metric and the value is the access level
  """
  def access_map(), do: @access_map

  # Private functions

  defp metric_not_available_error(metric, opts \\ [])

  defp metric_not_available_error(metric, opts) do
    type = Keyword.get(opts, :type, :all)
    %{close: close, error_msg: error_msg} = metric_not_available_error_details(metric, type)

    case close do
      nil -> {:error, error_msg}
      close -> {:error, error_msg <> " Did you mean '#{close}'?"}
    end
  end

  defp metric_not_available_error_details(metric, :all) do
    %{
      close: Enum.find(@metrics_mapset, fn m -> String.jaro_distance(metric, m) > 0.8 end),
      error_msg: "The metric '#{metric}' is not supported or is mistyped."
    }
  end

  defp metric_not_available_error_details(metric, :timeseries) do
    %{
      close:
        Enum.find(@timeseries_metrics_mapset, fn m -> String.jaro_distance(metric, m) > 0.8 end),
      error_msg: "The timeseries metric '#{metric}' is not supported or is mistyped."
    }
  end

  defp metric_not_available_error_details(metric, :histogram) do
    %{
      close:
        Enum.find(@histogram_metrics_mapset, fn m -> String.jaro_distance(metric, m) > 0.8 end),
      error_msg: "The histogram metric '#{metric}' is not supported or is mistyped."
    }
  end
end