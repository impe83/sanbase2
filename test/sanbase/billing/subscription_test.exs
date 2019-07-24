defmodule Sanbase.Billing.SubscriptionTest do
  use SanbaseWeb.ConnCase

  import Sanbase.Factory
  import SanbaseWeb.Graphql.TestHelpers

  alias Sanbase.Billing.Subscription
  alias Sanbase.Auth.Apikey
  alias Sanbase.Repo

  setup do
    free_user = insert(:user)
    user = insert(:staked_user)
    conn = setup_jwt_auth(build_conn(), user)

    product = insert(:product)
    plan_essential = insert(:plan_essential, product: product)
    plan_pro = insert(:plan_pro, product: product)
    insert(:plan_premium, product: product)

    {:ok, apikey} = Apikey.generate_apikey(user)
    conn_apikey = setup_apikey_auth(build_conn(), apikey)

    {:ok, apikey_free} = Apikey.generate_apikey(free_user)
    conn_apikey_free = setup_apikey_auth(build_conn(), apikey_free)

    {:ok,
     conn: conn,
     user: user,
     product: product,
     plan_essential: plan_essential,
     plan_pro: plan_pro,
     conn_apikey: conn_apikey,
     conn_apikey_free: conn_apikey_free}
  end

  describe "#is_restricted?" do
    test "network_growth and mvrv_ratio are restricted" do
      assert Subscription.is_restricted?(:network_growth)
      assert Subscription.is_restricted?(:mvrv_ratio)
    end

    test "all_projects and history_price are not restricted" do
      refute Subscription.is_restricted?(:all_projects)
      refute Subscription.is_restricted?(:history_price)
    end
  end

  describe "#needs_advanced_plan?" do
    test "mvrv_ratio needs advanced plan subscription" do
      assert Subscription.needs_advanced_plan?(:mvrv_ratio)
    end

    test "network_growth, all_projects and history_price does not need advanced plan subscription" do
      refute Subscription.needs_advanced_plan?(:network_growth)
      refute Subscription.needs_advanced_plan?(:all_projects)
      refute Subscription.needs_advanced_plan?(:history_price)
    end
  end

  describe "#has_access?" do
    test "subscription to ESSENTIAL plan has access to STANDART metrics", context do
      subscription = insert(:subscription_essential, user: context.user) |> Repo.preload(:plan)

      assert Subscription.has_access?(subscription, :network_growth)
    end

    test "subscription to ESSENTIAL plan does not have access to ADVANCED metrics", context do
      subscription = insert(:subscription_essential, user: context.user) |> Repo.preload(:plan)

      refute Subscription.has_access?(subscription, :mvrv_ratio)
    end

    test "subscription to ESSENTIAL plan has access to not restricted metrics", context do
      subscription = insert(:subscription_essential, user: context.user) |> Repo.preload(:plan)

      assert Subscription.has_access?(subscription, :history_price)
    end

    test "subscription to PRO plan have access to both STANDART and ADVANCED metrics", context do
      subscription = insert(:subscription_pro, user: context.user) |> Repo.preload(:plan)

      assert Subscription.has_access?(subscription, :network_growth)
      assert Subscription.has_access?(subscription, :mvrv_ratio)
    end

    test "subscription to PRO plan has access to not restricted metrics", context do
      subscription = insert(:subscription_pro, user: context.user) |> Repo.preload(:plan)

      assert Subscription.has_access?(subscription, :history_price)
    end
  end

  describe "#user_subscriptions" do
    test "when there are subscriptions - currentUser return list of subscriptions", context do
      insert(:subscription_essential, user: context.user)

      subscription = Subscription.user_subscriptions(context.user) |> hd()
      assert subscription.plan.name == "ESSENTIAL"
    end

    test "when there are no subscriptions - return []", context do
      assert Subscription.user_subscriptions(context.user) == []
    end

    test "only active subscriptions", context do
      insert(:subscription_essential,
        user: context.user,
        cancel_at_period_end: true,
        current_period_end: Timex.shift(Timex.now(), days: -1)
      )

      assert Subscription.user_subscriptions(context.user) == []
    end
  end

  describe "#current_subscription" do
    test "when there is subscription - return it", context do
      insert(:subscription_essential, user: context.user)

      current_subscription = Subscription.current_subscription(context.user, context.product.id)
      assert current_subscription.plan.id == context.plan_essential.id
    end

    test "when there isn't - return nil", context do
      current_subscription = Subscription.current_subscription(context.user, context.product.id)
      assert current_subscription == nil
    end

    test "only active subscriptions", context do
      insert(:subscription_essential,
        user: context.user,
        cancel_at_period_end: true,
        current_period_end: Timex.shift(Timex.now(), days: -1)
      )

      current_subscription = Subscription.current_subscription(context.user, context.product.id)
      assert current_subscription == nil
    end
  end
end