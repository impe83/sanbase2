defmodule SanbaseWeb.Graphql.UserSettingsTypes do
  use Absinthe.Schema.Notation

  enum :newsletter_subscription_type do
    value(:weekly)
    value(:daily)
    value(:off)
  end

  object :user_settings do
    field(:hide_privacy_data, :boolean)
    field(:is_beta_mode, :boolean)
    field(:is_promoter, :boolean)
    field(:theme, :string)
    field(:page_size, :integer)
    field(:table_columns, :json)
    field(:has_telegram_connected, :boolean)
    field(:signal_notify_telegram, :boolean)
    field(:signal_notify_email, :boolean)
    field(:newsletter_subscription, :newsletter_subscription_type)
    field(:paid_with, :string)
    field(:signals_per_day, :integer)
  end

  input_object :user_settings_input_object do
    field(:hide_privacy_data, :boolean)
    field(:is_beta_mode, :boolean)
    field(:theme, :string)
    field(:page_size, :integer)
    field(:table_columns, :json)
    field(:has_telegram_connected, :boolean)
    field(:signal_notify_telegram, :boolean)
    field(:signal_notify_email, :boolean)
    field(:newsletter_subscription, :newsletter_subscription_type)
    field(:signals_per_day, :integer)
  end
end
