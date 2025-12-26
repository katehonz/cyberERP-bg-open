defmodule CyberCore.Email.PasswordResetEmail do
  @moduledoc """
  Email templates за възстановяване на парола.
  """

  import Swoosh.Email

  @doc """
  Създава email за възстановяване на парола.
  """
  def password_reset_email(user, token, base_url) do
    reset_url = "#{base_url}/reset-password/#{token}"

    new()
    |> to({user.first_name || user.email, user.email})
    |> subject("Cyber ERP - Възстановяване на парола")
    |> html_body(password_reset_html(user, reset_url))
    |> text_body(password_reset_text(user, reset_url))
  end

  defp password_reset_html(user, reset_url) do
    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
    </head>
    <body style="margin: 0; padding: 0; background-color: #111827; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;">
      <div style="max-width: 600px; margin: 0 auto; padding: 40px 20px;">
        <!-- Header -->
        <div style="text-align: center; margin-bottom: 40px;">
          <div style="display: inline-block; background: linear-gradient(135deg, #10b981, #06b6d4); width: 80px; height: 80px; border-radius: 16px; line-height: 80px; margin-bottom: 20px;">
            <span style="color: #111827; font-size: 32px; font-weight: bold;">CE</span>
          </div>
          <h1 style="color: #10b981; font-size: 28px; margin: 0; letter-spacing: 2px;">CYBER ERP</h1>
          <p style="color: #059669; font-size: 12px; margin-top: 8px; font-family: monospace;">[ PASSWORD RESET REQUEST ]</p>
        </div>

        <!-- Content Card -->
        <div style="background-color: rgba(31, 41, 55, 0.8); border: 1px solid rgba(16, 185, 129, 0.2); border-radius: 16px; padding: 32px; margin-bottom: 24px;">
          <p style="color: #d1d5db; font-size: 16px; margin-top: 0;">
            Здравейте#{if user.first_name, do: ", #{user.first_name}", else: ""},
          </p>

          <p style="color: #9ca3af; font-size: 14px; line-height: 1.6;">
            Получихме заявка за възстановяване на паролата за вашия акаунт в Cyber ERP.
            Ако не сте направили тази заявка, моля игнорирайте този имейл.
          </p>

          <div style="text-align: center; margin: 32px 0;">
            <a href="#{reset_url}"
               style="display: inline-block; background: linear-gradient(135deg, #10b981, #06b6d4); color: #111827; font-size: 16px; font-weight: bold; text-decoration: none; padding: 16px 48px; border-radius: 8px; font-family: monospace; letter-spacing: 1px;">
              НУЛИРАНЕ НА ПАРОЛА
            </a>
          </div>

          <p style="color: #6b7280; font-size: 12px; line-height: 1.6;">
            Или копирайте този линк във вашия браузър:<br>
            <a href="#{reset_url}" style="color: #10b981; word-break: break-all;">#{reset_url}</a>
          </p>

          <div style="background-color: rgba(245, 158, 11, 0.1); border: 1px solid rgba(245, 158, 11, 0.3); border-radius: 8px; padding: 16px; margin-top: 24px;">
            <p style="color: #fbbf24; font-size: 12px; margin: 0;">
              ⚠️ <strong>Внимание:</strong> Този линк е валиден само 1 час.
              След това ще трябва да заявите нов линк за възстановяване.
            </p>
          </div>
        </div>

        <!-- Footer -->
        <div style="text-align: center; color: #4b5563; font-size: 12px;">
          <p style="margin: 0;">
            <span style="display: inline-block; width: 8px; height: 8px; background-color: #10b981; border-radius: 50%; margin-right: 8px;"></span>
            SYSTEM ONLINE | Cyber ERP
          </p>
          <p style="margin-top: 16px; color: #374151; font-size: 11px;">
            Този имейл е изпратен автоматично. Моля не отговаряйте на него.
          </p>
        </div>
      </div>
    </body>
    </html>
    """
  end

  defp password_reset_text(user, reset_url) do
    """
    CYBER ERP - Възстановяване на парола
    =====================================

    Здравейте#{if user.first_name, do: ", #{user.first_name}", else: ""},

    Получихме заявка за възстановяване на паролата за вашия акаунт в Cyber ERP.
    Ако не сте направили тази заявка, моля игнорирайте този имейл.

    За да възстановите паролата си, отворете следния линк:
    #{reset_url}

    Внимание: Този линк е валиден само 1 час.

    --
    Cyber ERP
    Този имейл е изпратен автоматично. Моля не отговаряйте на него.
    """
  end
end
