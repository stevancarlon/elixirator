defmodule Elixirator.MissionInput do
  @moduledoc "Changeset validation for spacecraft dry mass; no database is required."
  import Ecto.Changeset

  def changeset(params) do
    {%{}, %{mass: :decimal}}
    |> cast(params, [:mass])
    |> validate_required([:mass])
    |> validate_number(:mass, greater_than: 0, less_than_or_equal_to: Elixirator.Fuel.max_mass())
    |> Map.put(:action, :validate)
  end
end
