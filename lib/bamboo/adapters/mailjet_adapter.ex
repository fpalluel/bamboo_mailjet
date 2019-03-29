defmodule Bamboo.MailjetAdapter do
  @moduledoc """
  Sends email using Mailjet's API.

  Use this adapter to send emails through Mailjet's API. Requires that both an API and
  a private API keys are set in the config.

  ## Example config

      # In config/config.exs, or config.prod.exs, etc.
      config :my_app, MyApp.Mailer,
        adapter: Bamboo.MailjetAdapter,
        api_key: "my_api_key",
        api_private_key: "my_private_api_key"

      # Define a Mailer. Maybe in lib/my_app/mailer.ex
      defmodule MyApp.Mailer do
        use Bamboo.Mailer, otp_app: :my_app
      end

   Note: Mailjet provides a "recipients" feature. From the documentation: The recipients
   listed in **Recipients** will each receive a separate message without showing all the
   other recipients.
   To make use of it in Bamboo, when creating an email, set the "BCC" field only,
   leaving the TO and CC field empty.

   If TO and/or CC field are set, this adapter will generate the TO, CC and BCC
   fields in the "traditional" way.
  """

  @default_base_uri "https://api.mailjet.com/v3"
  @send_message_path "/send"
  @behaviour Bamboo.Adapter

  alias Bamboo.Email

  defmodule ApiError do
    defexception [:message]

    def exception(%{message: message}) do
      %ApiError{message: message}
    end

    def exception(%{params: params, response: response}) do
      message = """
      There was a problem sending the email through the Mailjet API.

      Here is the response:

      #{inspect(response, limit: :infinity)}

      Here are the params we sent:

      #{inspect(params, limit: :infinity)}

      """

      %ApiError{message: message}
    end
  end

  def deliver(email, config) do
    api_key = get_key(config, :api_key)
    api_private_key = get_key(config, :api_private_key)
    body = email |> to_mailjet_body |> Poison.encode!()
    url = [base_uri(), @send_message_path]

    case :hackney.post(url, gen_headers(api_key, api_private_key), body, [:with_body]) do
      {:ok, status, _headers, response} when status > 299 ->
        raise(ApiError, %{params: body, response: response})

      {:ok, status, headers, response} ->
        %{status_code: status, headers: headers, body: response}

      {:error, reason} ->
        raise(ApiError, %{message: inspect(reason)})
    end
  end

  @doc false
  def handle_config(config) do
    cond do
      config[:api_key] in [nil, "", ''] -> raise_key_error(config, :api_key)
      config[:api_private_key] in [nil, "", ''] -> raise_key_error(config, :api_private_key)
      true -> config
    end
  end

  defp get_key(config, key) do
    case Map.get(config, key) do
      nil -> raise_key_error(config, key)
      key -> key
    end
  end

  defp raise_key_error(config, key) do
    raise ArgumentError, """
    There was no #{key} set for the Mailjet adapter.

    * Here are the config options that were passed in:

    #{inspect(config)}
    """
  end

  defp gen_headers(api_key, api_private_key) do
    [
      {"Content-Type", "application/json"},
      {"Authorization", "Basic " <> Base.encode64("#{api_key}:#{api_private_key}")}
    ]
  end

  defp to_mailjet_body(%Email{} = email) do
    %{}
    |> put_from(email)
    |> put_subject(email)
    |> put_html_body(email)
    |> put_text_body(email)
    |> put_recipients(email)
    |> put_template_id(email)
    |> put_template_language(email)
    |> put_vars(email)
    |> put_custom_id(email)
    |> put_event_payload(email)
  end

  defp put_from(body, %Email{from: address}) when is_binary(address),
    do: Map.put(body, :fromemail, address)

  defp put_from(body, %Email{from: {name, address}}) when name in [nil, "", ''],
    do: Map.put(body, :fromemail, address)

  defp put_from(body, %Email{from: {name, address}}) do
    body
    |> Map.put(:fromemail, address)
    |> Map.put(:fromname, name)
  end

  defp put_to(body, %Email{to: []}), do: body

  defp put_to(body, %Email{to: to}) do
    Map.put(body, :to, to |> addresses)
  end

  defp put_cc(body, %Email{cc: []}), do: body

  defp put_cc(body, %Email{cc: cc}) do
    Map.put(body, :cc, cc |> addresses)
  end

  defp put_bcc(body, %Email{bcc: []}), do: body

  defp put_bcc(body, %Email{bcc: bcc}) do
    Map.put(body, :bcc, bcc |> addresses)
  end

  defp put_recipients(body, %{to: [], cc: [], bcc: bcc}),
    do: Map.put(body, :recipients, bcc |> recipients)

  defp put_recipients(body, email) do
    body
    |> put_to(email)
    |> put_cc(email)
    |> put_bcc(email)
  end

  defp put_subject(body, %Email{subject: subject}), do: Map.put(body, :subject, subject)

  defp put_html_body(body, %Email{html_body: nil}), do: body

  defp put_html_body(body, %Email{html_body: html_body}),
    do: Map.put(body, "html-part", html_body)

  defp put_text_body(body, %Email{text_body: nil}), do: body

  defp put_text_body(body, %Email{text_body: text_body}),
    do: Map.put(body, "text-part", text_body)

  defp put_template_id(body, %Email{private: %{mj_templateid: id}}),
    do: Map.put(body, "mj-templateid", id)

  defp put_template_id(body, _email), do: body

  defp put_template_language(body, %Email{private: %{mj_templatelanguage: active}}),
    do: Map.put(body, "mj-templatelanguage", active)

  defp put_template_language(body, _email), do: body

  defp put_vars(body, %Email{private: %{mj_vars: vars}}), do: Map.put(body, "vars", vars)
  defp put_vars(body, _email), do: body

  defp put_custom_id(body, %Email{private: %{mj_custom_id: custom_id}}),
    do: Map.put(body, "Mj-CustomID", custom_id)

  defp put_custom_id(body, _email), do: body

  defp put_event_payload(body, %Email{private: %{mj_event_payload: event_payload}}),
    do: Map.put(body, "Mj-EventPayLoad", event_payload)

  defp put_event_payload(body, _email), do: body

  defp recipients(new_recipients) do
    new_recipients
    |> Enum.reduce([], fn recipient, recipients ->
      recipients ++ get_recipient_output(recipient)
    end)
  end

  defp get_recipient_output(recipient) when is_binary(recipient), do: [%{email: recipient}]
  defp get_recipient_output({name, email}) when name in [nil, '', ""], do: [%{email: email}]
  defp get_recipient_output({name, email}), do: [%{name: name, email: email}]

  defp addresses(new_addresses) do
    new_addresses
    |> Enum.reduce([], fn address, addresses ->
      addresses ++ get_address_output(address)
    end)
    |> Enum.join(",")
  end

  defp get_address_output(address) when is_binary(address), do: [address]
  defp get_address_output({name, email}) when name in [nil, '', ""], do: [email]
  defp get_address_output({name, email}), do: [name <> " <" <> email <> ">"]

  defp base_uri do
    Application.get_env(:bamboo, :mailjet_base_uri) || @default_base_uri
  end
end
