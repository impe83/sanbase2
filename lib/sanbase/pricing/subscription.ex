defmodule Sanbase.Pricing.Subscription do
  @moduledoc """
  Module for managing user subscriptions - create, upgrade/downgrade, cancel.
  Also containing some helper functions that take user subscription as argument and
  return some properties of the subscription plan.
  """
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias Sanbase.Pricing.{Plan, Subscription}
  alias Sanbase.Pricing.Plan.AccessSeed
  alias Sanbase.Auth.User
  alias Sanbase.Repo
  alias Sanbase.StripeApi

  require Logger

  @generic_error_message """
  Current subscription attempt failed. Please, contact administrator of the site for more information.
  """
  @percent_discount_1000_san 20
  @percent_discount_200_san 4

  schema "subscriptions" do
    field(:stripe_id, :string)
    field(:active, :boolean, null: false, default: false)
    field(:current_period_end, :utc_datetime)
    field(:cancel_at_period_end, :boolean, null: false, default: false)
    belongs_to(:user, User)
    belongs_to(:plan, Plan)
  end

  def generic_error_message, do: @generic_error_message

  def changeset(%Subscription{} = subscription, attrs \\ %{}) do
    subscription
    |> cast(attrs, [
      :plan_id,
      :user_id,
      :stripe_id,
      :active,
      :current_period_end,
      :cancel_at_period_end
    ])
  end

  @doc """
  Subscribe user with card_token to a plan.

  - Create or update a Stripe customer with card details contained by the card_token param.
  - Create subscription record in Stripe.
  - Create a subscription record locally so we can check access control without calling Stripe.
  """
  def subscribe(user_id, card_token, plan_id) do
    with {:user?, %User{} = user} <- {:user?, Repo.get(User, user_id)},
         {:plan?, %Plan{} = plan} <- {:plan?, Repo.get(Plan, plan_id)},
         {:ok, %User{stripe_customer_id: stripe_customer_id} = user}
         when not is_nil(stripe_customer_id) <-
           create_or_update_stripe_customer(user, card_token),
         {:ok, stripe_subscription} <- create_stripe_subscription(user, plan),
         {:ok, subscription} <- create_subscription_db(stripe_subscription, user, plan) do
      {:ok, subscription |> Repo.preload(plan: [:product])}
    else
      result ->
        handle_subscription_error_result(result, "Subscription attempt failed", %{
          user_id: user_id,
          plan_id: plan_id
        })
    end
  end

  @doc """
  Upgrade or Downgrade plan:

  - Updates subcription in Stripe with new plan.
  - Updates local subscription
  Stripe docs:   https://stripe.com/docs/billing/subscriptions/upgrading-downgrading#switching
  """
  def update_subscription(user_id, subscription_id, plan_id) do
    with {:subscription?, %Subscription{user_id: ^user_id} = subscription} <-
           {:subscription?, Repo.get(Subscription, subscription_id) |> Repo.preload(:plan)},
         {:plan?, %Plan{} = new_plan} <- {:plan?, Repo.get(Plan, plan_id)},
         {:ok, item_id} <-
           StripeApi.get_subscription_first_item_id(subscription.stripe_id),

         # Note: that will generate dialyzer error because the spec is wrong.
         # More info here: https://github.com/code-corps/stripity_stripe/pull/499
         {:ok, _} <-
           StripeApi.update_subscription(subscription.stripe_id, %{
             items: [
               %{
                 id: item_id,
                 plan: subscription.plan.stripe_id
               }
             ]
           }),
         {:ok, updated_subscription} <-
           update_subscription_db(subscription, %{plan_id: new_plan.id}) do
      {:ok, updated_subscription |> Repo.preload([plan: [:product]], force: true)}
    else
      result ->
        handle_subscription_error_result(result, "Upgrade/Downgrade failed", %{
          user_id: user_id,
          subscription_id: subscription_id,
          plan_id: plan_id
        })
    end
  end

  @doc """
  Cancel subscription:

  Cancellation means scheduling for cancellation. It updates the `cancel_at_period_end` field which will cancel the
  subscription at `current_period_end`. That allows user to use the subscription for the time left that he has already paid for.
  https://stripe.com/docs/billing/subscriptions/canceling-pausing#canceling
  """
  def cancel_subscription(user_id, subscription_id) do
    with {:subscription?, %Subscription{user_id: ^user_id} = subscription} <-
           {:subscription?, Repo.get(Subscription, subscription_id)},
         {:ok, _} <-
           StripeApi.cancel_subscription(subscription.stripe_id),
         {:ok, _} <- update_subscription_db(subscription, %{cancel_at_period_end: true}) do
      {:ok,
       %{
         scheduled_for_cancellation: true,
         scheduled_for_cancellation_at: subscription.current_period_end
       }}
    else
      result ->
        handle_subscription_error_result(
          result,
          "Canceling subscription failed",
          %{user_id: user_id, subscription_id: subscription_id}
        )
    end
  end

  @doc """
  List all active user subscriptions with plans and products.
  """
  def user_subscriptions(user) do
    user
    |> user_subscriptions_query()
    |> Repo.all()
    |> Repo.preload(plan: [:product])
  end

  @doc """
  Current subscription is the last active subscription for a product.
  """
  def current_subscription(user, product_id) do
    user
    |> user_subscriptions_query()
    |> last_subscription_for_product_query(product_id)
    |> Repo.one()
    |> Repo.preload(plan: [:product])
  end

  @doc """
  By subscription and query name determines whether subscription can access the query.
  """
  def has_access?(subscription, query) do
    case needs_advanced_plan?(query) do
      true -> subscription_access?(subscription, query)
      false -> true
    end
  end

  @doc """
  How much historical days a subscription plan can access.
  """
  def historical_data_in_days(subscription) do
    subscription.plan.access["historical_data_in_days"]
  end

  @doc """
  Checks whether a query is in any plan.
  """
  def is_restricted?(query) do
    query in AccessSeed.all_restricted_metrics()
  end

  def needs_advanced_plan?(query) do
    advanced_metrics = AccessSeed.advanced_metrics()
    standart_metrics = AccessSeed.standart_metrics()

    query in advanced_metrics and query not in standart_metrics
  end

  def plan_name(subscription) do
    subscription.plan.name
  end

  # private functions

  defp handle_subscription_error_result(result, log_message, params) do
    case result do
      {:user?, _} ->
        reason = "Cannot find user with id #{params.user_id}"
        Logger.error("#{log_message} - reason: #{reason}")
        {:error, reason}

      {:plan?, _} ->
        reason = "Cannot find plan with id #{params.plan_id}"
        Logger.error("#{log_message} - reason: #{reason}")
        {:error, reason}

      {:subscription?, _} ->
        reason =
          "Cannot find subscription with id #{params.subscription_id} for user with id #{
            params.user_id
          }. Either this subscription doesn not exist or it does not belong to the user."

        Logger.error("#{log_message} - reason: #{reason}")
        {:error, reason}

      {:current_subscription?, nil} ->
        reason =
          "Current user with user id: #{params.user_id} does not have active subscriptions."

        Logger.error("#{log_message} - reason: #{reason}")
        {:error, reason}

      {:error, reason} ->
        Logger.error("#{log_message} - reason: #{inspect(reason)}")
        {:error, @generic_error_message}
    end
  end

  defp create_or_update_stripe_customer(%User{stripe_customer_id: stripe_id} = user, card_token)
       when is_nil(stripe_id) do
    StripeApi.create_customer(user, card_token)
    |> case do
      {:ok, stripe_customer} ->
        user
        |> User.changeset(%{stripe_customer_id: stripe_customer.id})
        |> Repo.update()

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp create_or_update_stripe_customer(%User{stripe_customer_id: stripe_id} = user, card_token)
       when is_binary(stripe_id) do
    StripeApi.update_customer(user, card_token)
  end

  defp create_stripe_subscription(user, plan) do
    subscription = %{
      customer: user.stripe_customer_id,
      items: [%{plan: plan.stripe_id}]
    }

    user
    |> User.san_balance!()
    |> percent_discount()
    |> update_subscription_with_coupon(subscription)
    |> case do
      {:ok, subscription} ->
        StripeApi.create_subscription(subscription)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp create_subscription_db(stripe_subscription, user, plan) do
    %Subscription{}
    |> Subscription.changeset(%{
      stripe_id: stripe_subscription.id,
      user_id: user.id,
      plan_id: plan.id,
      active: true,
      current_period_end: DateTime.from_unix!(stripe_subscription.current_period_end)
    })
    |> Repo.insert()
  end

  defp update_subscription_db(subscription, params) do
    subscription
    |> Subscription.changeset(params)
    |> Repo.update()
  end

  defp update_subscription_with_coupon(nil, subscription), do: subscription

  defp update_subscription_with_coupon(percent_off, subscription) do
    StripeApi.create_coupon(%{percent_off: percent_off, duration: "forever"})
    |> case do
      {:ok, coupon} ->
        {:ok, Map.put(subscription, :coupon, coupon.id)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp percent_discount(balance) when balance >= 1000, do: @percent_discount_1000_san
  defp percent_discount(balance) when balance >= 200, do: @percent_discount_200_san
  defp percent_discount(_), do: nil

  defp subscription_access?(nil, _query), do: false

  defp subscription_access?(subscription, query) do
    query in subscription.plan.access["metrics"]
  end

  defp user_subscriptions_query(user) do
    from(s in Subscription,
      where: s.user_id == ^user.id and s.active == true,
      order_by: [desc: s.id]
    )
  end

  defp last_subscription_for_product_query(query, product_id) do
    from(s in query,
      where: s.plan_id in fragment("select id from plans where product_id = ?", ^product_id),
      limit: 1
    )
  end
end
