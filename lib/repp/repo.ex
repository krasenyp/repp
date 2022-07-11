defmodule Repp.Repo do
  use Ecto.Repo,
    otp_app: :repp,
    adapter: Ecto.Adapters.Postgres
end
