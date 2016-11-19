# BambooMailjet

This is a [Mailjet](https://www.mailjet.com) adapter for the [Bamboo](https://github.com/thoughtbot/bamboo) email app.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add `bamboo_mailjet` to your list of dependencies in `mix.exs`:
    ```elixir
    def deps do
      [{:bamboo_mailjet, "~> 0.0.1"}]
    end
    ```
  2. Ensure `bamboo_mailjet` is started before your application:
    ```elixir
    def application do
      [applications: [:bamboo_mailjet]]
    end
    ```
  3. Update your config file with your API keys, given that you properly set up a **Bamboo** mailer.
    ```elixir
    # In config/config.exs, or config.prod.exs, etc.
    config :my_app, MyApp.Mailer,
      adapter: Bamboo.MailjetAdapter,
      api_key: "my_api_key",
      api_private_key: "my_private_api_key"
    ```

 **Note:** Mailjet provides a "recipients" feature. From the Mailjet documentation:
> The recipients listed in **Recipients** will each receive a separate message without showing all the
> other recipients.

 To make use of this feature with Bamboo, when creating an email, set the "BCC" field only, leaving the TO and CC field empty.

 If TO and/or CC field are set, this adapter will generate the TO, CC and BCC fields in the "traditional" way.
