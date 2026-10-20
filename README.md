# Elixirator

An interplanetary fuel calculator built with **Elixir, Phoenix 1.8, and LiveView**. Build a flight path through Earth, the Moon, and Mars; fuel requirements update as the spacecraft mass or route changes.

**No database is used.** No PostgreSQL, SQLite, Repo, migrations, or database environment variables are needed. Ecto provides in-memory changeset validation only, and `phoenix_ecto` connects those changesets to Phoenix forms. Mission state lives in each LiveView process and resets on a new visit.

## Run locally

Prerequisites: Elixir 1.15+ and a compatible Erlang/OTP installation. Development was verified with Elixir 1.20.2 / OTP 29. Git is needed to fetch Heroicons. Node.js is not required; Mix installs standalone Tailwind and esbuild binaries.

```sh
mix setup
mix phx.server
```

Open [localhost:4000](http://localhost:4000). `PORT=4001 mix phx.server` selects another port.

If Hex or Rebar is not installed yet, run `mix local.hex --force` and `mix local.rebar --force` first. Linux users may optionally install `inotify-tools` for automatic browser reload while editing; the app works without it.

## Features

- Real-time mass and route editing with server-side validation.
- Add, remove, reorder, or clear flight steps.
- Compact action and planet popovers with keyboard navigation, typeahead, and native form value synchronization.
- Apollo 11, Mars, and passenger ship presets.
- Total fuel, dry mass, total liftoff mass, and an expandable breakdown for each burn.
- Responsive custom Tailwind CSS interface, labeled controls, keyboard focus states, live result announcements, and reduced-motion support.
- All computation runs in Elixir. There are no external APIs or JavaScript fuel calculations.

## Calculation

For a single burn, calculate and round down:

```text
launch: floor(mass × gravity × 0.042 − 33)
landing: floor(mass × gravity × 0.033 − 42)
```

Repeat the same formula with the previous fuel increment as the new mass. Add positive increments until the next increment is zero or negative. For the supplied Earth landing example:

```text
28,801 kg spacecraft
9,278 + 2,960 + 915 + 254 + 40 = 13,447 kg fuel
```

For a mission, traverse the route **backward**. The payload for each burn is the dry spacecraft mass plus all fuel already required for later burns. This ensures earlier stages carry the later stages' fuel.

Gravity is represented in thousandths (Earth: 9807, Moon: 1620, Mars: 3711), and coefficients use integer ratios. Decimal arithmetic avoids binary floating-point drift before flooring. Fractional spacecraft masses are supported; fuel is expressed in whole kilograms.

| Reference mission | Dry mass | Route | Expected fuel |
| --- | ---: | --- | ---: |
| Apollo 11 | 28,801 kg | Launch Earth → Land Moon → Launch Moon → Land Earth | 51,898 kg |
| Mars mission | 14,606 kg | Launch Earth → Land Mars → Launch Mars → Land Earth | 33,388 kg |
| Passenger ship | 75,432 kg | Launch Earth → Land Moon → Launch Moon → Land Mars → Launch Mars → Land Earth | 212,161 kg |

The planner permits any sequence of supported actions and planets; it does not impose physical itinerary rules that the challenge did not request. An empty route requires zero fuel. Inputs are bounded to 24 steps and a positive dry mass of at most 1,000,000,000 kg. Invalid inputs hide previous results until corrected.

## Structure

```text
lib/elixirator/fuel.ex                  Pure calculation and domain validation
lib/elixirator/mission_input.ex         In-memory spacecraft mass changeset
lib/elixirator/step_input.ex            In-memory action/planet changeset
lib/elixirator/missions.ex              Reference presets
lib/elixirator_web/live/mission_live.*  LiveView event handling and UI
lib/elixirator_web/components/          Shared layout, inputs, icons, notifications
lib/elixirator_web/components/mission_components.ex  Presets, flight steps, and result panels
assets/css/app.css                     Custom Tailwind v4 styling
```

The route editor uses LiveView streams with stable step IDs. A bounded in-memory plan retains the ordering required for backward calculation. No LiveComponents, database, account system, or persistence service is necessary.

## Checks

```sh
mix precommit
mix assets.build
node --test assets/js/hooks/*.test.mjs
```

`mix precommit` compiles with warnings treated as errors, checks unused locked dependencies, formats the source, and runs ExUnit. Tests cover all three mission totals, recursive increments, future-fuel weight, flooring, fractional and invalid masses, unsupported selections, empty/oversized routes, presets, edits, reordering, removal, and validation recovery.

GitHub Actions runs formatting, compilation, tests, and an asset build on pushes and pull requests.

The dropdown hook tests use Node.js 22+ and its built-in test runner, with no npm dependencies. Node.js is only needed for these tests, not to build or run the app. They cover keyboard selection, cancellation, typeahead, LiveView updates, dismissal, cleanup, and viewport positioning; they do not replace browser interaction testing.

## Production build

```sh
MIX_ENV=prod mix deps.get --only prod
MIX_ENV=prod mix compile
MIX_ENV=prod mix assets.deploy
MIX_ENV=prod mix release
```

Run the release with `PHX_SERVER=true`, `PHX_HOST`, `PORT`, and `SECRET_KEY_BASE` set in the environment. Generate the secret with `mix phx.gen.secret`. The supplied production configuration assumes TLS terminates at a reverse proxy. No database setup is required.

## Image credits

Planet imagery is bundled locally in `priv/static/images/planets/`; the app makes no external image requests.

- Earth: [NASA/Goddard, Blue Marble](https://images.nasa.gov/details/GSFC_20171208_Archive_e002131).
- Moon: [NASA, full Moon phase](https://science.nasa.gov/moon/moon-phases/).
- Mars: [NASA, Mars facts](https://science.nasa.gov/mars/facts/).

The original images are displayed with circular CSS crops.
