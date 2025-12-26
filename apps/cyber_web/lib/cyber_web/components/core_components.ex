defmodule CyberWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.
  """
  use Phoenix.Component

  alias Phoenix.LiveView.JS

  @doc """
  Renders flash notices.
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :kind, :atom, values: [:info, :error], doc: "the kind of flash message"

  def flash(assigns) do
    ~H"""
    <div
      :if={msg = Phoenix.Flash.get(@flash, @kind)}
      id={"flash-#{@kind}"}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("#flash-#{@kind}")}
      role="alert"
      class={[
        "fixed top-2 right-2 mr-2 w-80 sm:w-96 z-50 rounded-lg p-3 ring-1",
        @kind == :info && "bg-emerald-50 text-emerald-800 ring-emerald-500 fill-cyan-900",
        @kind == :error && "bg-rose-50 text-rose-900 shadow-md ring-rose-500 fill-rose-900"
      ]}
    >
      <p class="flex items-center gap-1.5 text-sm font-semibold leading-6">
        <.icon :if={@kind == :info} name="hero-information-circle-mini" class="h-4 w-4" />
        <.icon :if={@kind == :error} name="hero-exclamation-circle-mini" class="h-4 w-4" />
        <%= msg %>
      </p>
      <button type="button" class="group absolute top-1 right-1 p-2" aria-label="close">
        <.icon name="hero-x-mark-solid" class="h-5 w-5 opacity-40 group-hover:opacity-70" />
      </button>
    </div>
    """
  end

  @doc """
  Renders a flash group.
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  def flash_group(assigns) do
    ~H"""
    <.flash kind={:info} flash={@flash} />
    <.flash kind={:error} flash={@flash} />
    """
  end

  @doc """
  Renders a simple icon from Heroicons.
  """
  attr :name, :string, required: true
  attr :class, :string, default: nil

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all transform ease-in duration-200",
         "opacity-100 translate-y-0 sm:translate-x-0",
         "opacity-0 translate-y-2 sm:translate-y-0 sm:translate-x-2"}
    )
  end

  @doc """
  Renders a modal.
  """
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :on_cancel, :any, default: %JS{}
  slot :inner_block, required: true

  def modal(assigns) do
    assigns = assign(assigns, :on_cancel_js, build_on_cancel(assigns.on_cancel))

    ~H"""
    <div
      id={@id}
      phx-mounted={@show && show_modal(@id)}
      phx-remove={hide_modal(@id)}
      data-cancel={@on_cancel_js}
      class="relative z-50 hidden"
    >
      <div id={"#{@id}-bg"} class="bg-zinc-50/90 fixed inset-0 transition-opacity" aria-hidden="true" />
      <div
        class="fixed inset-0 overflow-y-auto"
        aria-labelledby={"#{@id}-title"}
        aria-describedby={"#{@id}-description"}
        role="dialog"
        aria-modal="true"
        tabindex="0"
      >
        <div class="flex min-h-full items-center justify-center">
          <div class="w-full max-w-3xl p-4 sm:p-6 lg:py-8">
            <.focus_wrap
              id={"#{@id}-container"}
              phx-window-keydown={JS.exec("data-cancel", to: "##{@id}")}
              phx-key="escape"
              phx-click-away={JS.exec("data-cancel", to: "##{@id}")}
              class="shadow-zinc-700/10 ring-zinc-700/10 relative hidden rounded-2xl bg-white p-14 shadow-lg ring-1 transition"
            >
              <div class="absolute top-6 right-5">
                <button
                  phx-click={JS.exec("data-cancel", to: "##{@id}")}
                  type="button"
                  class="-m-3 flex-none p-3 opacity-20 hover:opacity-40"
                  aria-label="close"
                >
                  <.icon name="hero-x-mark-solid" class="h-5 w-5" />
                </button>
              </div>
              <div id={"#{@id}-content"}>
                <%= render_slot(@inner_block) %>
              </div>
            </.focus_wrap>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a simple form wrapper that forwards assigns to `<.form>` and renders optional action slots.
  """
  attr :for, :any, required: true
  attr :as, :any, default: nil
  attr :multipart, :boolean, default: false
  attr :rest, :global
  slot :inner_block, required: true
  slot :actions

  def simple_form(assigns) do
    ~H"""
    <.form for={@for} as={@as} multipart={@multipart} {@rest}>
      <%= render_slot(@inner_block) %>

      <div :if={@actions != []} class="mt-6 flex items-center gap-3">
        <%= for action <- @actions do %>
          <%= render_slot(action) %>
        <% end %>
      </div>
    </.form>
    """
  end

  @doc """
  Standardised form input component supporting text, number, select and textarea inputs.
  """
  attr :field, Phoenix.HTML.FormField, required: true
  attr :label, :string, default: nil
  attr :type, :string, default: "text"
  attr :options, :list, default: []
  attr :prompt, :string, default: nil
  attr :rows, :integer, default: 3

  attr :rest, :global,
    include: ~w(step min max placeholder autocomplete disabled readonly required)

  def input(%{type: "textarea"} = assigns) do
    assigns = assign_default_label(assigns)

    ~H"""
    <div class="flex flex-col gap-1">
      <label for={@field.id} class="text-sm font-medium text-gray-700"><%= @label %></label>
      <textarea id={@field.id} name={@field.name} rows={@rows} class="rounded-md border-gray-300 text-sm shadow-sm focus:border-indigo-500 focus:ring-indigo-500" {@rest}>
        <%= Phoenix.HTML.Form.input_value(@field.form, @field.field) %>
      </textarea>
      <.input_errors field={@field} />
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    assigns = assign_default_label(assigns)

    assigns =
      assign(
        assigns,
        :input_value,
        Phoenix.HTML.Form.input_value(assigns.field.form, assigns.field.field)
      )

    ~H"""
    <div class="flex flex-col gap-1">
      <label for={@field.id} class="text-sm font-medium text-gray-700"><%= @label %></label>
      <select id={@field.id} name={@field.name} class="rounded-md border-gray-300 text-sm shadow-sm focus:border-indigo-500 focus:ring-indigo-500" {@rest}>
        <option :if={@prompt} value=""><%= @prompt %></option>
        <%= Phoenix.HTML.Form.options_for_select(@options, @input_value) %>
      </select>
      <.input_errors field={@field} />
    </div>
    """
  end

  def input(assigns) do
    assigns = assign_default_label(assigns)

    assigns =
      assign(
        assigns,
        :input_value,
        Phoenix.HTML.Form.input_value(assigns.field.form, assigns.field.field)
      )

    ~H"""
    <div class="flex flex-col gap-1">
      <label for={@field.id} class="text-sm font-medium text-gray-700"><%= @label %></label>
      <input
        type={@type}
        id={@field.id}
        name={@field.name}
        value={@input_value}
        class="rounded-md border-gray-300 text-sm shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
        {@rest}
      />
      <.input_errors field={@field} />
    </div>
    """
  end

  @doc """
  Primary button component used across forms.
  """
  attr :type, :string, default: "submit"

  attr :class, :string,
    default:
      "inline-flex items-center gap-2 rounded-md bg-indigo-600 px-4 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-700"

  attr :rest, :global
  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button type={@type} class={@class} {@rest}>
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  attr :field, Phoenix.HTML.FormField, required: true

  defp input_errors(assigns) do
    assigns = assign(assigns, :messages, error_messages(assigns.field))

    ~H"""
    <p :for={msg <- @messages} class="mt-2 text-sm text-red-600"><%= msg %></p>
    """
  end

  defp error_messages(%Phoenix.HTML.FormField{errors: errors}) do
    Enum.map(errors, &translate_error/1)
  end

  defp assign_default_label(assigns) do
    assign_new(assigns, :label, fn ->
      assigns.field.field
      |> to_string()
      |> Phoenix.Naming.humanize()
    end)
  end

  defp translate_error({msg, opts}) when is_binary(msg) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end

  defp translate_error(msg) when is_binary(msg), do: msg

  defp show_modal(js \\ %JS{}, id) when is_binary(id) do
    js
    |> JS.show(to: "##{id}")
    |> JS.show(
      to: "##{id}-bg",
      transition: {"transition-all transform ease-out duration-300", "opacity-0", "opacity-100"}
    )
    |> JS.show(
      to: "##{id}-container",
      transition:
        {"transition-all transform ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
    |> JS.add_class("overflow-hidden", to: "body")
    |> JS.focus_first(to: "##{id}-content")
  end

  defp hide_modal(js \\ %JS{}, id) do
    js
    |> JS.hide(
      to: "##{id}-bg",
      transition: {"transition-all transform ease-in duration-200", "opacity-100", "opacity-0"}
    )
    |> JS.hide(
      to: "##{id}-container",
      time: 200,
      transition:
        {"transition-all transform ease-in duration-200",
         "opacity-100 translate-y-0 sm:translate-x-0",
         "opacity-0 translate-y-2 sm:translate-y-0 sm:translate-x-2"}
    )
    |> JS.hide(to: "##{id}", transition: {"block", "block", "hidden"})
    |> JS.remove_class("overflow-hidden", to: "body")
    |> JS.pop_focus()
  end

  defp build_on_cancel(%JS{} = js), do: JS.exec(js, "phx-remove")
  defp build_on_cancel(path) when is_binary(path), do: JS.exec(JS.patch(path), "phx-remove")
  defp build_on_cancel(_), do: JS.exec(%JS{}, "phx-remove")
end
