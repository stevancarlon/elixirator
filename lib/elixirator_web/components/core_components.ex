defmodule ElixiratorWeb.CoreComponents do
  @moduledoc "Shared, accessible form controls, notifications, and Heroicons."
  use Phoenix.Component

  alias Phoenix.LiveView.JS

  attr :id, :string, default: nil
  attr :flash, :map, default: %{}
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error]
  attr :rest, :global
  slot :inner_block

  def flash(assigns) do
    assigns = assign(assigns, :id, assigns.id || "flash-#{assigns.kind}")

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      role="alert"
      class="fixed top-4 right-4 z-50"
      {@rest}
    >
      <div class={[
        "flex items-center gap-3 rounded-xl bg-neutral-900 p-4 shadow-xl w-80 sm:w-96 max-w-[90vw] text-wrap",
        if(@kind == :info, do: "text-neutral-200", else: "text-white border-l-2 border-white")
      ]}>
        <.icon name="hero-information-circle" class="size-5 shrink-0" />
        <div class="flex-1">
          <p :if={@title} class="font-semibold">{@title}</p>
          <p>{msg}</p>
        </div>
        <button
          type="button"
          class="grid size-10 place-items-center rounded hover:bg-white/10"
          phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
          aria-label="Dismiss notification"
        >
          <.icon name="hero-x-mark" class="size-5" />
        </button>
      </div>
    </div>
    """
  end

  attr :field, Phoenix.HTML.FormField, required: true
  attr :type, :string, default: "text"
  attr :label, :string, default: nil
  attr :class, :any, default: "mission-input"
  attr :options, :list, default: []

  attr :rest, :global,
    include:
      ~w(autocomplete disabled max maxlength min minlength placeholder readonly required step)

  def input(assigns) do
    errors = if Phoenix.Component.used_input?(assigns.field), do: assigns.field.errors, else: []
    assigns = assign(assigns, :errors, Enum.map(errors, &translate_error/1))

    ~H"""
    <div class="fieldset">
      <label
        :if={@label}
        for={if(@type == "select", do: "#{@field.id}-trigger", else: @field.id)}
        class="input-label mb-1"
      >
        {@label}
      </label>
      <%= if @type == "select" do %>
        <.select_input
          field={@field}
          label={@label}
          class={@class}
          options={@options}
          errors={@errors}
          rest={@rest}
        />
      <% else %>
        <input
          id={@field.id}
          name={@field.name}
          type={@type}
          value={Phoenix.HTML.Form.normalize_value(@type, @field.value)}
          class={@class}
          aria-invalid={to_string(@errors != [])}
          aria-describedby={@errors != [] && "#{@field.id}-errors"}
          {@rest}
        />
      <% end %>
      <div :if={@errors != []} id={"#{@field.id}-errors"}>
        <p :for={error <- @errors} class="mt-2 flex items-center gap-2 text-xs text-neutral-200">
          <.icon name="hero-exclamation-circle" class="size-4 shrink-0" />{error}
        </p>
      </div>
    </div>
    """
  end

  defp select_input(assigns) do
    selected_label =
      Enum.find_value(assigns.options, "Select", fn {label, value} ->
        if to_string(value) == to_string(assigns.field.value), do: label
      end)

    assigns =
      assign(assigns,
        selected_label: selected_label,
        disabled: Map.get(assigns.rest, :disabled, false)
      )

    ~H"""
    <div class="select-wrap">
      <select
        id={@field.id}
        name={@field.name}
        class="native-select"
        tabindex="-1"
        aria-hidden="true"
        {@rest}
      >
        {Phoenix.HTML.Form.options_for_select(@options, @field.value)}
      </select>
      <div
        id={"#{@field.id}-control"}
        phx-hook="Select"
        phx-update="ignore"
        data-input-id={@field.id}
        data-value={@field.value}
        data-invalid={to_string(@errors != [])}
        data-disabled={to_string(@disabled)}
      >
        <button
          type="button"
          id={"#{@field.id}-trigger"}
          class={[@class, "select-trigger"]}
          role="combobox"
          aria-label={@label}
          aria-haspopup="listbox"
          aria-expanded="false"
          aria-controls={"#{@field.id}-listbox"}
          aria-invalid={to_string(@errors != [])}
          aria-describedby={@errors != [] && "#{@field.id}-errors"}
          disabled={@disabled}
        >
          <span data-select-label>
            {@selected_label}
          </span>
          <.icon name="hero-chevron-down" class="select-chevron size-3.5" />
        </button>
        <div
          id={"#{@field.id}-listbox"}
          role="listbox"
          aria-label={@label}
          class="select-menu"
          hidden
        >
          <div
            :for={{label, value} <- @options}
            id={"#{@field.id}-option-#{value}"}
            role="option"
            data-value={value}
            aria-selected={to_string(to_string(value) == to_string(@field.value))}
            class="select-option"
          >
            <span data-option-label>{label}</span>
            <.icon name="hero-check" class="select-check size-4" />
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :icon, :string, required: true
  attr :disabled, :boolean, default: false
  attr :rest, :global

  def icon_button(assigns) do
    ~H"""
    <button
      id={@id}
      type="button"
      class="icon-button"
      aria-label={@label}
      title={@label}
      disabled={@disabled}
      {@rest}
    >
      <.icon name={@icon} class="size-4" />
    </button>
    """
  end

  attr :name, :string, required: true
  attr :class, :any, default: "size-4"

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} aria-hidden="true" />
    """
  end

  def show(js \\ %JS{}, selector), do: JS.show(js, to: selector)
  def hide(js \\ %JS{}, selector), do: JS.hide(js, to: selector)

  defp translate_error({message, options}) do
    Enum.reduce(options, message, fn {key, value}, text ->
      String.replace(text, "%{#{key}}", to_string(value))
    end)
  end
end
