defmodule Elixirator.Fuel do
  @moduledoc """
  Pure fuel calculations for the challenge's three celestial bodies.

  Missions are evaluated backwards: each burn carries the fuel needed for every
  later burn. Each burn recursively includes fuel for its own fuel. Gravity and
  coefficients use integer ratios to avoid floating-point rounding at boundaries.
  """

  @gravities %{"earth" => 9807, "moon" => 1620, "mars" => 3711}
  @coefficients %{"launch" => {42, 33}, "land" => {33, 42}}
  @max_steps 24
  @max_mass 1_000_000_000

  def max_steps, do: @max_steps
  def max_mass, do: @max_mass
  def planets, do: ~w(earth moon mars)
  def actions, do: ~w(launch land)

  @doc "Returns a total and a chronological breakdown, or a validation error."
  def calculate(mass, steps) when is_list(steps) do
    with {:ok, mass} <- positive_mass(mass),
         :ok <- validate_steps(steps),
         {breakdown, total} = calculate_steps(mass, steps) do
      {:ok, %{total: total, mass: mass, wet_mass: Decimal.add(mass, total), steps: breakdown}}
    end
  end

  def calculate(_, _), do: {:error, :invalid_steps}

  defp positive_mass(mass) do
    case Decimal.cast(mass) do
      {:ok, %Decimal{coef: coef} = value} when is_integer(coef) ->
        if Decimal.positive?(value) and Decimal.compare(value, @max_mass) != :gt,
          do: {:ok, value},
          else: {:error, :invalid_mass}

      _ ->
        {:error, :invalid_mass}
    end
  end

  defp validate_steps(steps) do
    cond do
      length(steps) > @max_steps -> {:error, :too_many_steps}
      Enum.all?(steps, &valid_step?/1) -> :ok
      true -> {:error, :invalid_steps}
    end
  end

  defp valid_step?(%{action: action, planet: planet}),
    do: action in actions() and planet in planets()

  defp valid_step?(_), do: false

  defp calculate_steps(mass, steps) do
    steps
    |> Enum.reverse()
    |> Enum.reduce({[], 0}, fn %{action: action, planet: planet} = step,
                               {breakdown, carried_fuel} ->
      payload = Decimal.add(mass, carried_fuel)
      increments = increments(payload, action, planet, [])
      fuel = Enum.sum(increments)

      result = Map.merge(step, %{fuel: fuel, payload: payload, increments: increments})
      {[result | breakdown], carried_fuel + fuel}
    end)
  end

  defp increments(mass, action, planet, acc) do
    {coefficient, offset} = Map.fetch!(@coefficients, action)

    fuel =
      mass
      |> Decimal.mult(Map.fetch!(@gravities, planet) * coefficient)
      |> Decimal.div(1_000_000)
      |> Decimal.sub(offset)
      |> Decimal.round(0, :floor)
      |> Decimal.to_integer()

    if fuel <= 0, do: Enum.reverse(acc), else: increments(fuel, action, planet, [fuel | acc])
  end
end
