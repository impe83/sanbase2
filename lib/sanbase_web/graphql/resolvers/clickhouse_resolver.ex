defmodule SanbaseWeb.Graphql.Resolvers.ClickhouseResolver do
  require Logger

  alias Sanbase.Model.Project
  alias Sanbase.DateTimeUtils
  alias SanbaseWeb.Graphql.Helpers.Utils

  alias Sanbase.Clickhouse.{
    DailyActiveDeposits,
    GasUsed,
    HistoricalBalance,
    MiningPoolsDistribution,
    MVRV,
    NetworkGrowth,
    NVT,
    RealizedValue,
    TopHolders
  }

  @one_hour_seconds 3600

  def top_holders_percent_of_total_supply(
        _root,
        %{slug: slug, number_of_holders: number_of_holders, from: from, to: to},
        _resolution
      ) do
    case TopHolders.percent_of_total_supply(slug, number_of_holders, from, to) do
      {:ok, percent_of_total_supply} ->
        {:ok, percent_of_total_supply}

      {:error, error} ->
        error_msg = "Can't calculate Top holders - percent of total supply."
        Logger.warn(error_msg <> " Reason: #{inspect(error)}")
        {:error, error_msg}
    end
  end

  def gas_used(
        _root,
        %{from: from, to: to, interval: interval},
        _resolution
      ) do
    case GasUsed.gas_used(from, to, interval) do
      {:ok, gas_used} ->
        {:ok, gas_used}

      {:error, error} ->
        error_msg = "Can't calculate Gas used."
        Logger.warn(error_msg <> " Reason: #{inspect(error)}")
        {:error, error_msg}
    end
  end

  def network_growth(_root, args, _resolution) do
    interval = DateTimeUtils.compound_duration_to_seconds(args.interval)

    with {:ok, contract, _} <- Project.contract_info_by_slug(args.slug),
         {:ok, network_growth} <-
           NetworkGrowth.network_growth(contract, args.from, args.to, interval) do
      {:ok, network_growth}
    else
      error ->
        Logger.error("Can't calculate network growth. Reason: #{inspect(error)}")

        {:error, "Can't calculate network growth"}
    end
  end

  def mining_pools_distribution(
        _root,
        %{from: from, to: to, interval: interval},
        _resolution
      ) do
    case MiningPoolsDistribution.distribution(from, to, interval) do
      {:ok, distribution} ->
        {:ok, distribution}

      {:error, error} ->
        error_msg = "Can't calculate mining pools distribution."
        Logger.warn(error_msg <> " Reason: #{inspect(error)}")
        {:error, error_msg}
    end
  end

  def mvrv_ratio(_root, args, _resolution) do
    # TODO: Check if interval is a whole day as in token circulation
    with {:ok, mvrv_ratio} <- MVRV.mvrv_ratio(args.slug, args.from, args.to, args.interval) do
      {:ok, mvrv_ratio}
    else
      {:error, error} ->
        Logger.warn(
          "Can't calculate MVRV ratio for project with coinmarketcap_id: #{args.slug}. Reason: #{
            inspect(error)
          }"
        )

        {:error, "Can't calculate MVRV ratio"}
    end
  end

  def daily_active_deposits(
        _root,
        %{slug: slug, from: from, to: to, interval: interval},
        _resolution
      ) do
    with {:ok, contract, _} <- Project.contract_info_by_slug(slug),
         {:ok, from, to, interval} <-
           Utils.calibrate_interval(
             DailyActiveDeposits,
             contract,
             from,
             to,
             interval,
             @one_hour_seconds,
             50
           ),
         {:ok, active_deposits} <-
           DailyActiveDeposits.active_deposits(contract, from, to, interval) do
      {:ok, active_deposits}
    else
      {:error, error} ->
        error_msg =
          "Can't calculate daily active deposits for project with coinmarketcap_id: #{slug}."

        Logger.warn(error_msg <> " Reason: #{inspect(error)}")
        {:error, error_msg}
    end
  end

  def realized_value(
        _root,
        %{slug: slug, from: from, to: to, interval: interval},
        _resolution
      ) do
    case RealizedValue.realized_value(slug, from, to, interval) do
      {:ok, realized_value} ->
        {:ok, realized_value}

      {:error, error} ->
        error_msg = "Can't calculate Realized Value for project with coinmarketcap_id: #{slug}."
        Logger.warn(error_msg <> " Reason: #{inspect(error)}")
        {:error, error_msg}
    end
  end

  def nvt_ratio(
        _root,
        %{slug: slug, from: from, to: to, interval: interval},
        _resolution
      ) do
    with {:ok, nvt_ratio} <- NVT.nvt_ratio(slug, from, to, interval) do
      {:ok, nvt_ratio}
    else
      {:error, error} ->
        error_msg = "Can't calculate NVT ratio for project with coinmarketcap_id: #{slug}."
        Logger.warn(error_msg <> " Reason: #{inspect(error)}")
        {:error, error_msg}
    end
  end

  def historical_balance(
        _root,
        %{slug: slug, from: from, to: to, interval: interval, address: address},
        _resolution
      ) do
    with {:ok, result} <- HistoricalBalance.historical_balance(address, slug, from, to, interval) do
      {:ok, result}
    else
      {:error, error} ->
        Logger.warn(
          "Can't calculate historical balances for project with coinmarketcap_id #{slug}. Reason: #{
            inspect(error)
          }"
        )

        {:error, "Can't calculate historical balances for project with coinmarketcap_id #{slug}"}
    end
  end
end
