defmodule ElixiratorWeb.MissionLive do
  use ElixiratorWeb, :live_view

  alias Elixirator.{Fuel, MissionInput, Missions, StepInput}
  import ElixiratorWeb.MissionComponents

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> initialize_planner()
      |> load_mission(Missions.default_id())

    {:ok, socket}
  end

  defp initialize_planner(socket) do
    socket
    |> assign(
      page_title: "Mission planner",
      preset: nil,
      plan: %{steps: []},
      next_id: 1,
      form: to_form(MissionInput.changeset(%{}), as: :mission),
      result: nil,
      step_count: 0
    )
    |> stream(:steps, [])
  end

  defp load_mission(socket, preset) do
    case Missions.fetch(preset) do
      {:ok, %{path: path, mass: mass}} when is_list(path) ->
        steps = build_steps(path)
        form = to_form(MissionInput.changeset(%{"mass" => mass}), as: :mission)

        socket
        |> clear_flash(:error)
        |> assign(
          preset: preset,
          plan: %{steps: steps},
          next_id: length(steps) + 1,
          form: form
        )
        |> recalculate()

      _ ->
        put_flash(socket, :error, "Unable to load this mission. Choose another preset.")
    end
  end

  defp build_steps(path) do
    path
    |> Enum.with_index(1)
    |> Enum.map(fn {planet, index} ->
      %{
        id: Integer.to_string(index),
        params: %{
          "action" => if(rem(index, 2) == 1, do: "launch", else: "land"),
          "planet" => planet
        }
      }
    end)
  end

  defp recalculate(socket) do
    %{plan: %{steps: steps}, form: %{source: mass_changeset}} = socket.assigns

    steps =
      Enum.map(steps, fn %{params: params} = step ->
        Map.put(step, :changeset, StepInput.changeset(params))
      end)

    result = calculate_result(mass_changeset, steps)

    socket
    |> assign(result: result, step_count: length(steps))
    |> stream(:steps, step_rows(steps, result), reset: true)
  end

  defp calculate_result(mass_changeset, steps) do
    with true <- mass_changeset.valid? && Enum.all?(steps, & &1.changeset.valid?),
         mass = Ecto.Changeset.get_field(mass_changeset, :mass),
         {:ok, result} <- Fuel.calculate(mass, calculation_path(steps)) do
      result
    else
      false -> nil
      {:error, _reason} -> nil
    end
  end

  defp calculation_path(steps) do
    Enum.map(steps, fn step ->
      step.changeset
      |> Ecto.Changeset.apply_changes()
      |> Map.put(:id, step.id)
    end)
  end

  defp step_rows(steps, result) do
    results_by_id = if result, do: Map.new(result.steps, &{&1.id, &1}), else: %{}

    steps
    |> Enum.with_index(1)
    |> Enum.map(fn {step, index} ->
      %{
        id: step.id,
        index: index,
        planet: step.params["planet"],
        form: to_form(step.changeset, as: :step, id: "step-#{step.id}"),
        result: Map.get(results_by_id, step.id)
      }
    end)
  end

  defp update_plan(socket, steps) do
    socket
    |> assign(plan: %{steps: steps}, preset: nil)
    |> recalculate()
  end

  @impl true
  def handle_event("preset", %{"mission" => preset}, socket) do
    {:noreply, load_mission(socket, preset)}
  end

  def handle_event("mass", %{"mission" => params}, socket) do
    {:noreply,
     socket
     |> assign(
       form: to_form(MissionInput.changeset(params), as: :mission),
       preset: nil
     )
     |> recalculate()}
  end

  def handle_event("step", %{"id" => id, "step" => params}, socket) do
    steps =
      Enum.map(socket.assigns.plan.steps, fn step ->
        if step.id == id, do: %{step | params: Map.take(params, ["action", "planet"])}, else: step
      end)

    {:noreply, update_plan(socket, steps)}
  end

  def handle_event("add-step", _, socket) do
    steps = socket.assigns.plan.steps

    if length(steps) < Fuel.max_steps() do
      previous = List.last(steps)
      action = if previous && previous.params["action"] == "launch", do: "land", else: "launch"
      planet = if previous, do: previous.params["planet"], else: "earth"

      step = %{
        id: Integer.to_string(socket.assigns.next_id),
        params: %{"action" => action, "planet" => planet}
      }

      {:noreply,
       socket |> assign(next_id: socket.assigns.next_id + 1) |> update_plan(steps ++ [step])}
    else
      {:noreply, socket}
    end
  end

  def handle_event("remove-step", %{"id" => id}, socket) do
    {:noreply, update_plan(socket, Enum.reject(socket.assigns.plan.steps, &(&1.id == id)))}
  end

  def handle_event("move-step", %{"id" => id, "direction" => direction}, socket) do
    steps = socket.assigns.plan.steps
    index = Enum.find_index(steps, &(&1.id == id))

    delta =
      case direction do
        "up" -> -1
        "down" -> 1
        _ -> 0
      end

    steps =
      if index && index + delta >= 0 && index + delta < length(steps) do
        step = Enum.at(steps, index)
        steps |> List.delete_at(index) |> List.insert_at(index + delta, step)
      else
        steps
      end

    {:noreply, update_plan(socket, steps)}
  end

  def handle_event("clear", _, socket), do: {:noreply, update_plan(socket, [])}
end
