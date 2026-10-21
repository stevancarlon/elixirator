# Elixirator

Interplanetary fuel calculator built with Elixir, Phoenix 1.8, and LiveView. Edit spacecraft mass and flight steps for Earth, Moon, and Mars to calculate fuel in real time. No database required.

## Run

Requires Elixir and Erlang/OTP. CI uses Elixir 1.18.4 and OTP 27.3.

```sh
mix setup
mix phx.server
```

Open [localhost:4000](http://localhost:4000).

## Checks

```sh
mix precommit
mix assets.build
```

ExUnit tests cover the three reference missions, recursive fuel calculations, validation, and LiveView route editing.

## Deploy on Render

Create a Render Blueprint from this repository using `render.yaml`. It provisions
a free Elixir web service, generates `SECRET_KEY_BASE`, and runs `./build.sh` to
compile assets and assemble a production release. No database is needed.

Phoenix uses Render's assigned hostname automatically; set `PHX_HOST` only when
using a custom domain. Free services sleep when idle, so the first visit may take
about a minute to load.

Planet images: NASA — [Earth](https://images.nasa.gov/details/GSFC_20171208_Archive_e002131), [Moon](https://science.nasa.gov/moon/moon-phases/), [Mars](https://science.nasa.gov/mars/facts/).
