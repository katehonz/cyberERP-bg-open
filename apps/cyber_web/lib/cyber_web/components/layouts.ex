defmodule CyberWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.
  """

  use CyberWeb, :live_view

  embed_templates "layouts/*"
end
