defmodule CyberCore.Email.DynamicMailer do
  @moduledoc """
  Динамичен mailer, който използва SMTP настройки от базата данни.
  """

  alias CyberCore.Settings

  @doc """
  Изпраща email използвайки SMTP настройките от базата данни.
  """
  def deliver(tenant_id, email) do
    case Settings.get_smtp_settings(tenant_id) do
      {:ok, config} ->
        mailer_config = build_mailer_config(config)
        Swoosh.Mailer.deliver(email, mailer_config)

      {:error, :smtp_not_configured} ->
        {:error, :smtp_not_configured}

      {:error, :smtp_disabled} ->
        {:error, :smtp_disabled}
    end
  end

  @doc """
  Изпраща email използвайки SMTP настройките от базата данни.
  Хвърля грешка при неуспех.
  """
  def deliver!(tenant_id, email) do
    case deliver(tenant_id, email) do
      {:ok, result} -> result
      {:error, reason} -> raise "Failed to send email: #{inspect(reason)}"
    end
  end

  @doc """
  Създава email с правилния from адрес от настройките.
  """
  def new_email(tenant_id) do
    case Settings.get_smtp_settings(tenant_id) do
      {:ok, config} ->
        from_email = Map.get(config, "from_email")
        from_name = Map.get(config, "from_name", "Cyber ERP")

        {:ok, Swoosh.Email.new(from: {from_name, from_email})}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Тества SMTP връзката.
  """
  def test_connection(tenant_id) do
    case new_email(tenant_id) do
      {:ok, base_email} ->
        config = Settings.get_smtp_settings(tenant_id)

        case config do
          {:ok, smtp_config} ->
            test_email =
              base_email
              |> Swoosh.Email.to(Map.get(smtp_config, "from_email"))
              |> Swoosh.Email.subject("Cyber ERP - Тест на SMTP връзка")
              |> Swoosh.Email.text_body("Ако получавате този email, SMTP настройките работят правилно.")
              |> Swoosh.Email.html_body("""
              <div style="font-family: Arial, sans-serif; padding: 20px;">
                <h2 style="color: #10b981;">Cyber ERP - SMTP Тест</h2>
                <p>Ако получавате този email, SMTP настройките работят правилно.</p>
                <p style="color: #666; font-size: 12px;">Това е автоматично генериран тестов email.</p>
              </div>
              """)

            deliver(tenant_id, test_email)

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private functions

  defp build_mailer_config(config) do
    port = parse_port(Map.get(config, "port", 587))
    ssl = Map.get(config, "ssl", false)
    tls = parse_tls(Map.get(config, "tls", :if_available))
    auth = parse_auth(Map.get(config, "auth", :always))

    [
      adapter: Swoosh.Adapters.SMTP,
      relay: Map.get(config, "host"),
      port: port,
      username: Map.get(config, "username"),
      password: Map.get(config, "password"),
      ssl: ssl,
      tls: tls,
      auth: auth,
      retries: 2,
      no_mx_lookups: false
    ]
  end

  defp parse_port(port) when is_integer(port), do: port
  defp parse_port(port) when is_binary(port), do: String.to_integer(port)
  defp parse_port(_), do: 587

  defp parse_tls(tls) when is_atom(tls), do: tls
  defp parse_tls("always"), do: :always
  defp parse_tls("never"), do: :never
  defp parse_tls("if_available"), do: :if_available
  defp parse_tls(_), do: :if_available

  defp parse_auth(auth) when is_atom(auth), do: auth
  defp parse_auth("always"), do: :always
  defp parse_auth("never"), do: :never
  defp parse_auth("if_available"), do: :if_available
  defp parse_auth(_), do: :always
end
