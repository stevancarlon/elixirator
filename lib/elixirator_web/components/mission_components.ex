defmodule ElixiratorWeb.MissionComponents do
  @moduledoc "Presentation components for mission presets, flight steps, and fuel results."
  use ElixiratorWeb, :html

  alias Elixirator.Missions

  attr :preset, :string, default: nil

  def mission_presets(assigns) do
    ~H"""
    <div class="presets" role="group" aria-label="Example missions">
      <button
        :for={{id, mission} <- Missions.list()}
        id={"preset-#{id}"}
        phx-click="preset"
        phx-value-mission={id}
        aria-pressed={@preset == id}
        class={["preset", @preset == id && "selected"]}
      >
        {mission.name}
      </button>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :step, :map, required: true
  attr :step_count, :integer, required: true

  def flight_step(assigns) do
    ~H"""
    <article id={@id} class="flight-step">
      <div class="step-number">{String.pad_leading(to_string(@step.index), 2, "0")}</div>
      <div class="step-body">
        <.form
          for={@step.form}
          id={"step-form-#{@step.id}"}
          phx-change="step"
          phx-submit="step"
          phx-value-id={@step.id}
          class="step-fields"
        >
          <.input
            field={@step.form[:action]}
            type="select"
            label="Action"
            options={[{"Launch", "launch"}, {"Land", "land"}]}
            class="mission-input"
          />
          <.input
            field={@step.form[:planet]}
            type="select"
            label="Planet"
            options={[{"Earth", "earth"}, {"Moon", "moon"}, {"Mars", "mars"}]}
            class="mission-input"
          />
        </.form>
        <details :if={@step.result} id={"burn-#{@step.id}"} class="burn-detail">
          <summary>
            <span class={["planet-dot", @step.planet]}></span>{number(@step.result.fuel)} kg fuel
            <.icon name="hero-chevron-down" class="size-3" />
          </summary>
          <div class="burn-math">
            <p>
              Payload: {number(@step.result.payload)} kg
            </p>
            <p>
              Fuel: {if(@step.result.increments == [],
                do: "0",
                else: Enum.map_join(@step.result.increments, " + ", &number/1)
              )} kg
            </p>
          </div>
        </details>
      </div>
      <div class="step-actions">
        <.icon_button
          id={"up-#{@step.id}"}
          label={"Move step #{@step.index} up"}
          icon="hero-arrow-up"
          disabled={@step.index == 1}
          phx-click="move-step"
          phx-value-id={@step.id}
          phx-value-direction="up"
        />
        <.icon_button
          id={"down-#{@step.id}"}
          label={"Move step #{@step.index} down"}
          icon="hero-arrow-down"
          disabled={@step.index == @step_count}
          phx-click="move-step"
          phx-value-id={@step.id}
          phx-value-direction="down"
        />
        <.icon_button
          id={"remove-#{@step.id}"}
          label={"Remove step #{@step.index}"}
          icon="hero-x-mark"
          disabled={false}
          phx-click="remove-step"
          phx-value-id={@step.id}
        />
      </div>
    </article>
    """
  end

  attr :result, :map, default: nil

  def fuel_summary(assigns) do
    ~H"""
    <section class="fuel-card" aria-labelledby="fuel-heading">
      <h2 id="fuel-heading">Total fuel</h2>
      <div id="fuel-result" aria-live="polite" aria-atomic="true">
        <%= if @result do %>
          <div class="total-fuel">
            <strong id="total-fuel">{number(@result.total)}</strong><span>kg</span>
          </div>
          <div class="mass-bar" aria-hidden="true">
            <span style={"width: #{Decimal.to_float(Decimal.div(@result.mass, @result.wet_mass)) * 100}%"}>
            </span>
          </div>
          <dl class="mass-breakdown">
            <div>
              <dt><span class="legend-dot dry"></span>Spacecraft mass</dt>
              <dd id="dry-mass">{number(@result.mass)} <span>kg</span></dd>
            </div>
            <div>
              <dt><span class="legend-dot fuel"></span>Fuel mass</dt>
              <dd>{number(@result.total)} <span>kg</span></dd>
            </div>
            <div class="wet-mass">
              <dt>Total liftoff mass</dt>
              <dd id="wet-mass">{number(@result.wet_mass)} <span>kg</span></dd>
            </div>
          </dl>
        <% else %>
          <div class="total-fuel"><strong>—</strong><span>kg</span></div>
          <p id="invalid-mission" class="validation-notice">
            Correct the invalid inputs.
          </p>
        <% end %>
      </div>
    </section>
    """
  end

  defp number(%Decimal{} = value),
    do: value |> Decimal.normalize() |> Decimal.to_string(:normal) |> group_number()

  defp number(value) when is_integer(value), do: value |> Integer.to_string() |> group_number()

  defp group_number(value) do
    case String.split(value, ".", parts: 2) do
      [integer] -> Regex.replace(~r/\B(?=(\d{3})+(?!\d))/, integer, ",")
      [integer, fraction] -> group_number(integer) <> "." <> fraction
    end
  end
end
