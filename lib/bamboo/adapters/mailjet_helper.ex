defmodule Bamboo.MailjetHelper do
  @moduledoc """
  Functions for using features specific to Mailjet
  """

  alias Bamboo.Email

  @doc """
  Set the template ID to use for the email contents.

  This overrides any message body provided.

  ## Example

      email
      |> template("4242")
  """
  def template(email, template_id) do
    Email.put_private(email, :mj_templateid, template_id)
  end

  @doc """
  Set whether to activate the interpretation of the template language.

  Defaults to false.

  ## Example

      email
      |> template_language(true)
  """
  def template_language(email, active) do
    Email.put_private(email, :mj_templatelanguage, active)
  end

  @doc """
  Add a variable to the email.

  This can be used for email personalization when using variables in the template.

  ## Example

      email
      |> put_var("name", "Arthur")
      |> put_var("reset_token", "8938463f-8910-461b-8b4b-e9d0368e979c")
  """
  def put_var(email, key, value) do
    vars = Map.get(email.private, :mj_vars, %{})
    Email.put_private(email, :mj_vars, Map.put(vars, key, value))
  end

  @doc """
  Add a custom id to the email

  this can be used to add a custom id to the email, which will be returned in the mailjet event callback api
  """
  def put_custom_id(email, value) do
    Email.put_private(email, :mj_custom_id, value)
  end

  @doc """
  Add a event payload to the email

  this can be used to add an event payload to the email, which will be returned in the mailjet event callback api
  """
  def put_event_payload(email, value) do
    Email.put_private(email, :mj_event_payload, value)
  end

  @doc """
  Add a monitoring category to the email, allowing to trigger alerts if the delivery fails.
  See the documentation : https://dev.mailjet.com/email/guides/send-api-V3/#real-time-monitoring
  """
  @spec put_monitoring_category(Email.t(), String.t()) :: Email.t()
  def put_monitoring_category(email, category) do
    Email.put_private(email, :mj_monitoring_category, category)
  end
end
