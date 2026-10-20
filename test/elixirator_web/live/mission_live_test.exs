defmodule ElixiratorWeb.MissionLiveTest do
  use ElixiratorWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  test "starts with Apollo and switches between reference missions", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")
    assert has_element?(view, "#mass-form input[value='28801']")
    assert has_element?(view, "#preset-apollo.selected")
    assert has_element?(view, "#total-fuel", "51,898")
    assert has_element?(view, "#wet-mass", "80,699")
    assert has_element?(view, "#flight-steps > article", "13,447 kg fuel")
    view |> element("#preset-mars") |> render_click()
    assert has_element?(view, "#total-fuel", "33,388")
    view |> element("#preset-passenger") |> render_click()
    assert has_element?(view, "#total-fuel", "212,161")
    assert has_element?(view, "#step-count", "6 steps")
  end

  test "mass changes update results and errors clear stale totals", %{conn: conn} do
    view = open_apollo(conn)
    view |> form("#mass-form", mission: %{mass: "1"}) |> render_change()
    assert has_element?(view, "#total-fuel", "0")

    for mass <- ["", "0", "-10", "1000000001"] do
      view |> form("#mass-form", mission: %{mass: mass}) |> render_change()
      assert has_element?(view, "#invalid-mission")
      refute has_element?(view, "#total-fuel")
    end

    view |> form("#mass-form", mission: %{mass: "28801.5"}) |> render_change()
    assert has_element?(view, "#total-fuel")
    assert has_element?(view, "#dry-mass", "28,801.5")
    refute has_element?(view, "#invalid-mission")
  end

  test "steps can be removed, added, edited, and cleared", %{conn: conn} do
    view = open_apollo(conn)
    view |> element("#clear-route") |> render_click()
    assert has_element?(view, "#step-count", "0 steps")
    refute has_element?(view, "#flight-steps > article")
    assert has_element?(view, "#total-fuel", "0")
    view |> element("#add-step") |> render_click()
    assert has_element?(view, "#step-form-5")
    view |> form("#step-form-5", step: %{action: "land", planet: "earth"}) |> render_change()
    assert has_element?(view, "#total-fuel", "13,447")
    view |> form("#step-form-5", step: %{action: "land", planet: "moon"}) |> render_change()
    refute has_element?(view, "#total-fuel", "13,447")
    view |> element("#remove-5") |> render_click()
    assert has_element?(view, "#total-fuel", "0")
  end

  test "reordering recalculates the route and keeps stable step identities", %{conn: conn} do
    view = open_apollo(conn)
    view |> element("#down-1") |> render_click()
    assert has_element?(view, "#flight-steps > article:nth-of-type(2) #step-form-1")
    refute has_element?(view, "#total-fuel", "51,898")
    view |> element("#up-1") |> render_click()
    assert has_element?(view, "#flight-steps > article:first-of-type #step-form-1")
    assert has_element?(view, "#total-fuel", "51,898")
  end

  test "invalid selection events do not crash or leave stale results", %{conn: conn} do
    view = open_apollo(conn)

    render_click(view, "step", %{
      "id" => "1",
      "step" => %{"action" => "fly", "planet" => "jupiter"}
    })

    assert has_element?(view, "#invalid-mission")
    refute has_element?(view, "#total-fuel")
    view |> element("#preset-apollo") |> render_click()
    assert has_element?(view, "#total-fuel", "51,898")
    render_click(view, "preset", %{"mission" => "unknown"})
    render_click(view, "move-step", %{"id" => "missing", "direction" => "up"})
    assert has_element?(view, "#total-fuel", "51,898")
  end

  test "caps the route length", %{conn: conn} do
    view = open_apollo(conn)
    for _ <- 1..20, do: view |> element("#add-step") |> render_click()
    assert has_element?(view, "#add-step[disabled]")
    assert has_element?(view, "#step-count", "24 steps")
    render_click(view, "add-step")
    assert has_element?(view, "#step-count", "24 steps")
  end

  test "an unavailable preset preserves the mission and a valid preset clears the error", %{
    conn: conn
  } do
    {:ok, view, _} = live(conn, ~p"/")
    view |> element("#preset-passenger") |> render_click()

    render_click(view, "preset", %{"mission" => "unknown"})

    assert has_element?(view, "#flash-error", "Unable to load this mission")
    assert has_element?(view, "#total-fuel", "212,161")
    assert has_element?(view, "#step-count", "6 steps")
    assert has_element?(view, "#preset-passenger.selected")

    view |> element("#preset-apollo") |> render_click()

    refute has_element?(view, "#flash-error")
    assert has_element?(view, "#total-fuel", "51,898")
  end

  test "correcting an invalid step restores totals and each burn breakdown", %{conn: conn} do
    view = open_apollo(conn)

    render_click(view, "step", %{
      "id" => "1",
      "step" => %{"action" => "fly", "planet" => "earth"}
    })

    assert has_element?(view, "#invalid-mission")
    refute has_element?(view, "#total-fuel")
    refute has_element?(view, "#flight-steps details")

    view |> form("#step-form-1", step: %{action: "launch", planet: "earth"}) |> render_change()

    refute has_element?(view, "#invalid-mission")
    assert has_element?(view, "#total-fuel", "51,898")
    assert has_element?(view, "#burn-1", "32,988 kg fuel")
    assert has_element?(view, "#burn-4", "13,447 kg fuel")
  end

  test "the maximum allowed mass calculates successfully", %{conn: conn} do
    view = open_apollo(conn)
    view |> form("#mass-form", mission: %{mass: "1000000000"}) |> render_change()

    assert has_element?(view, "#total-fuel")
    assert has_element?(view, "#dry-mass", "1,000,000,000")
    refute has_element?(view, "#invalid-mission")
  end

  test "custom planet menus expose accessible options and receive updated server values", %{
    conn: conn
  } do
    {:ok, view, _} = live(conn, ~p"/")
    assert has_element?(view, "#step-form-2 [role=combobox][aria-label=Planet]", "Moon")
    assert has_element?(view, "#step-form-2 [role=listbox][hidden]")
    assert has_element?(view, "#step-form-2 [role=option][data-value=moon][aria-selected=true]")

    view |> element("#preset-mars") |> render_click()

    assert has_element?(view, "#step-form-2 [phx-hook=Select][data-value=mars]")
    assert has_element?(view, "#total-fuel", "33,388")
  end

  test "action selectors update one step and restore the selection when loading a preset", %{
    conn: conn
  } do
    view = open_apollo(conn)

    assert has_element?(
             view,
             "#step-form-1 select[name=\"step[action]\"] option[value=launch][selected]"
           )

    assert has_element?(
             view,
             "#step-form-2 select[name=\"step[action]\"] option[value=land][selected]"
           )

    view |> form("#step-form-1", step: %{action: "land", planet: "earth"}) |> render_change()

    assert has_element?(
             view,
             "#step-form-1 select[name=\"step[action]\"] option[value=land][selected]"
           )

    refute has_element?(
             view,
             "#step-form-1 select[name=\"step[action]\"] option[value=launch][selected]"
           )

    assert has_element?(
             view,
             "#step-form-2 select[name=\"step[action]\"] option[value=land][selected]"
           )

    assert has_element?(
             view,
             "#step-form-3 select[name=\"step[action]\"] option[value=launch][selected]"
           )

    refute has_element?(view, "#total-fuel", "51,898")

    view |> element("#preset-apollo") |> render_click()

    assert has_element?(
             view,
             "#step-form-1 select[name=\"step[action]\"] option[value=launch][selected]"
           )

    assert has_element?(view, "#total-fuel", "51,898")
  end

  defp open_apollo(conn) do
    {:ok, view, _} = live(conn, ~p"/")
    view |> element("#preset-apollo") |> render_click()
    view
  end
end
