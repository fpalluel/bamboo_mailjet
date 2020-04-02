defmodule Bamboo.MailjetAdapterTest do
  use ExUnit.Case
  alias Bamboo.Email
  alias Bamboo.MailjetAdapter
  alias Bamboo.MailjetHelper

  @config %{adapter: MailjetAdapter, api_key: "123_abc", api_private_key: "321_cba"}
  @config_with_no_api_key %{adapter: MailjetAdapter, api_key: nil, api_private_key: "321_cba"}
  @config_with_no_api_private_key %{
    adapter: MailjetAdapter,
    api_key: "123_abc",
    api_private_key: nil
  }
  defmodule FakeMailjet do
    use Plug.Router

    plug(
      Plug.Parsers,
      parsers: [:urlencoded, :multipart, :json],
      pass: ["*/*"],
      json_decoder: Jason
    )

    plug(:match)
    plug(:dispatch)

    def start_server(parent) do
      Agent.start_link(fn -> %{} end, name: __MODULE__)
      Agent.update(__MODULE__, &Map.put(&1, :parent, parent))
      port = get_free_port()
      Application.put_env(:bamboo, :mailjet_base_uri, "http://localhost:#{port}")
      Plug.Cowboy.http(__MODULE__, [], port: port, ref: __MODULE__)
    end

    defp get_free_port do
      {:ok, socket} = :ranch_tcp.listen(port: 0)
      {:ok, port} = :inet.port(socket)
      :erlang.port_close(socket)
      port
    end

    def shutdown do
      Plug.Cowboy.shutdown(__MODULE__)
    end

    post "/send" do
      case Map.get(conn.params, "fromemail") do
        "INVALID_EMAIL" -> conn |> send_resp(500, "Error!!") |> send_to_parent
        _ -> conn |> send_resp(200, "SENT") |> send_to_parent
      end
    end

    defp send_to_parent(conn) do
      parent = Agent.get(__MODULE__, fn set -> Map.get(set, :parent) end)
      send(parent, {:fake_mailjet, conn})
      conn
    end
  end

  setup do
    FakeMailjet.start_server(self())

    on_exit(fn ->
      FakeMailjet.shutdown()
    end)

    :ok
  end

  test "raises if the api key is nil" do
    assert_raise ArgumentError, ~r/no api_key set/, fn ->
      new_email(from: "foo@bar.com") |> MailjetAdapter.deliver(@config_with_no_api_key)
    end

    assert_raise ArgumentError, ~r/no api_key set/, fn ->
      MailjetAdapter.handle_config(%{})
    end
  end

  test "raises if the api private key is nil" do
    assert_raise ArgumentError, ~r/no api_private_key set/, fn ->
      new_email(from: "foo@bar.com") |> MailjetAdapter.deliver(@config_with_no_api_private_key)
    end
  end

  test "deliver/2 sends the to the right url" do
    new_email() |> MailjetAdapter.deliver(@config)

    assert_receive {:fake_mailjet, %{request_path: request_path}}

    assert request_path == "/send"
  end

  test "deliver/2 sends from, html and text body, subject, headers and attachment" do
    email =
      new_email(
        from: "from@foo.com",
        subject: "My Subject",
        text_body: "TEXT BODY",
        html_body: "HTML BODY"
      )
      |> Email.put_header("Reply-To", "reply@foo.com")
      |> Email.put_attachment(Path.join(__DIR__, "../../../support/attachment.txt"))

    email |> MailjetAdapter.deliver(@config)

    assert_receive {:fake_mailjet, %{params: params, req_headers: headers}}

    assert params["From"]["Name"] == email.from |> elem(0)
    assert params["From"]["Email"] == email.from |> elem(1)
    assert params["Subject"] == email.subject
    assert params["TextPart"] == email.text_body
    assert params["HTMLPart"] == email.html_body

    assert Enum.member?(
             headers,
             {"authorization",
              "Basic " <> Base.encode64("#{@config[:api_key]}:#{@config[:api_private_key]}")}
           )

    assert params["Attachments"] == [
             %{
               "ContentType" => "text/plain",
               "Filename" => "attachment.txt",
               "Base64Content" => "VGVzdCBBdHRhY2htZW50Cg=="
             }
           ]
  end

  test "deliver/2 correctly formats TO,CC and BCC" do
    email =
      new_email(
        to: [{"foo1", "foo1@bar.com"}, {nil, "foo2@bar.com"}, "foo3@bar.com"],
        cc: [{"foo1", "foo1@bar.com"}, {nil, "foo2@bar.com"}, "foo3@bar.com"],
        bcc: [{"foo1", "foo1@bar.com"}, {nil, "foo2@bar.com"}, "foo3@bar.com"]
      )

    email |> MailjetAdapter.deliver(@config)

    assert_receive {:fake_mailjet, %{params: params}}
    refute Enum.member?(params, "recipients")

    assert params["To"] == [
             %{"Email" => "foo1@bar.com", "Name" => "foo1"},
             %{"Email" => "foo2@bar.com", "Name" => nil},
             %{"Email" => "foo3@bar.com", "Name" => nil}
           ]

    assert params["Cc"] == [
             %{"Email" => "foo1@bar.com", "Name" => "foo1"},
             %{"Email" => "foo2@bar.com", "Name" => nil},
             %{"Email" => "foo3@bar.com", "Name" => nil}
           ]

    assert params["Bcc"] == [
             %{"Email" => "foo1@bar.com", "Name" => "foo1"},
             %{"Email" => "foo2@bar.com", "Name" => nil},
             %{"Email" => "foo3@bar.com", "Name" => nil}
           ]
  end

  test "deliver/2 correctly formats Mailjet recipients" do
    email = new_email(bcc: [{"user1", "foo1@bar.com"}, {nil, "foo2@bar.com"}, "foo3@bar.com"])

    email |> MailjetAdapter.deliver(@config)

    assert_receive {:fake_mailjet, %{params: params}}

    assert params["Bcc"] == [
             %{"Email" => "foo1@bar.com", "Name" => "user1"},
             %{"Email" => "foo2@bar.com", "Name" => nil},
             %{"Email" => "foo3@bar.com", "Name" => nil}
           ]
  end

  test "deliver/2 sends template id and template language" do
    new_email(
      from: "from@foo.com",
      subject: "My Subject"
    )
    |> MailjetHelper.template("42")
    |> MailjetHelper.template_language(true)
    |> MailjetAdapter.deliver(@config)

    assert_receive {:fake_mailjet, %{params: params}}
    assert params["TemplateID"] == "42"
    assert params["TemplateLanguage"] == true
  end

  test "deliver/2 sends variables" do
    new_email(
      from: "from@foo.com",
      subject: "My Subject"
    )
    |> MailjetHelper.put_var("foo1", "bar1")
    |> MailjetHelper.put_var("foo2", "bar2")
    |> MailjetAdapter.deliver(@config)

    assert_receive {:fake_mailjet, %{params: params}}
    assert params["Variables"] == %{"foo1" => "bar1", "foo2" => "bar2"}
  end

  test "deliver/2 sends with custom id" do
    new_email(
      from: "from@foo.com",
      subject: "My Subject"
    )
    |> MailjetHelper.put_custom_id("customId1")
    |> MailjetAdapter.deliver(@config)

    assert_receive {:fake_mailjet, %{params: params}}
    assert params["CustomID"] == "customId1"
  end

  test "deliver/2 sends with event payload" do
    new_email(
      from: "from@foo.com",
      subject: "My Subject"
    )
    |> MailjetHelper.put_event_payload("customEventPayLoad")
    |> MailjetAdapter.deliver(@config)

    assert_receive {:fake_mailjet, %{params: params}}
    assert params["EventPayload"] == "customEventPayLoad"
  end

  test "raises if the response is not a success" do
    email = new_email(from: {"John", "me@example.com"})

    assert_raise Bamboo.MailjetAdapter.ApiError, fn ->
      email |> MailjetAdapter.deliver(@config)
    end
  end

  test "deliver/2 omits attachments key if no attachments" do
    email = new_email()
    email |> MailjetAdapter.deliver(@config)

    assert_receive {:fake_mailjet, %{params: params}}
    refute Map.has_key?(params, "attachments")
  end

  defp new_email(attrs \\ []) do
    attrs = Keyword.merge([from: "foo@bar.com", to: []], attrs)
    Email.new_email(attrs) |> Bamboo.Mailer.normalize_addresses()
  end
end
