defmodule Elixirator.StepInput do
  @moduledoc "Validates a single launch or landing using supported bodies."
  import Ecto.Changeset

  def changeset(params) do
    {%{}, %{action: :string, planet: :string}}
    |> cast(params, [:action, :planet])
    |> validate_required([:action, :planet])
    |> validate_inclusion(:action, Elixirator.Fuel.actions())
    |> validate_inclusion(:planet, Elixirator.Fuel.planets())
    |> Map.put(:action, :validate)
  end
end
