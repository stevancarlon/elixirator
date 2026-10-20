defmodule Elixirator.FuelTest do
  use ExUnit.Case, async: true

  alias Elixirator.Fuel

  test "Apollo 11 mission matches the reference total" do
    assert {:ok, result} = Fuel.calculate(28_801, route(~w(earth moon moon earth)))
    assert result.total == 51_898
    assert Decimal.equal?(result.wet_mass, 80_699)
    assert Enum.map(result.steps, & &1.planet) == ~w(earth moon moon earth)
    assert Enum.sum(Enum.map(result.steps, & &1.fuel)) == result.total
  end

  test "Mars mission matches the reference total" do
    assert {:ok, %{total: 33_388}} = Fuel.calculate(14_606, route(~w(earth mars mars earth)))
  end

  test "passenger ship matches the reference total" do
    assert {:ok, %{total: 212_161}} =
             Fuel.calculate(75_432, route(~w(earth moon moon mars mars earth)))
  end

  test "Earth landing recursively adds fuel for the fuel" do
    assert {:ok, %{total: 13_447, steps: [step]}} =
             Fuel.calculate(28_801, [%{action: "land", planet: "earth"}])

    assert step.increments == [9278, 2960, 915, 254, 40]
  end

  test "earlier burns carry fuel for all later burns" do
    assert {:ok, result} = Fuel.calculate(28_801, route(~w(earth moon moon earth)))
    [first | later] = result.steps
    assert Decimal.equal?(first.payload, 28_801 + Enum.sum(Enum.map(later, & &1.fuel)))
    assert Decimal.equal?(List.last(result.steps).payload, 28_801)
  end

  test "floors exactly at an integer boundary" do
    assert {:ok, %{steps: [step]}} =
             Fuel.calculate(1_000_000, [%{action: "launch", planet: "earth"}])

    assert hd(step.increments) == 411_861

    assert {:ok, %{steps: [step]}} =
             Fuel.calculate(Decimal.new("999999.999"), [%{action: "launch", planet: "earth"}])

    assert hd(step.increments) == 411_860
  end

  test "small or fractional positive masses never produce negative fuel" do
    for mass <- [1, 0.001, Decimal.new("0.5")] do
      assert {:ok, %{total: 0}} = Fuel.calculate(mass, route(~w(earth moon)))
    end
  end

  test "an empty route uses no fuel" do
    assert {:ok, %{total: 0, steps: []}} = Fuel.calculate(10, [])
  end

  test "invalid masses are rejected" do
    for mass <- [0, -1, "bad", nil, Decimal.new("NaN"), Decimal.new("Infinity"), 1_000_000_001] do
      assert {:error, :invalid_mass} = Fuel.calculate(mass, [])
    end
  end

  test "invalid selections, malformed paths, and excessive routes are rejected" do
    for path <- [
          [%{action: "fly", planet: "earth"}],
          [%{action: "land", planet: "jupiter"}],
          [%{}],
          [nil],
          "earth"
        ] do
      assert {:error, :invalid_steps} = Fuel.calculate(10, path)
    end

    assert {:error, :too_many_steps} =
             Fuel.calculate(10, List.duplicate(%{action: "land", planet: "earth"}, 25))
  end

  defp route(planets) do
    planets
    |> Enum.with_index()
    |> Enum.map(fn {planet, index} ->
      %{action: if(rem(index, 2) == 0, do: "launch", else: "land"), planet: planet}
    end)
  end
end
