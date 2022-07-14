defmodule Frugality do
  alias Frugality.Core.Conditions
  alias Frugality.Core.Metadata
  alias Frugality.Core.EntityTag

  import Plug.Conn

  defmacro __using__(_) do
    quote do
      plug Frugality.Plug

      import Frugality
    end
  end

  def put_generator(%Plug.Conn{} = conn, generator) do
    put_private(conn, :frugality_generator, generator)
  end

  def derive_metadata(%Plug.Conn{private: private} = conn, data) do
    generator = Access.fetch!(private, :frugality_generator)

    derive_metadata(conn, generator, data)
  end

  def derive_metadata(%Plug.Conn{} = conn, generator, data) do
    metadata =
      data
      |> Enum.into(%{})
      |> Map.put(:conn, conn)
      |> generator.derive()

    put_metadata(conn, metadata)
  end

  def put_metadata(%Plug.Conn{} = conn, metadata) do
    metadata
    |> normalize_metadata()
    |> Metadata.new()
    |> then(&put_private(conn, :frugality_metadata, {:derived, &1}))
  end

  defp normalize_metadata(metadata) do
    Enum.reduce(metadata, [], fn
      {_, nil}, acc ->
        acc

      {:entity_tag, raw}, acc when is_binary(raw) ->
        with {:ok, tag} <- EntityTag.from_string(raw) do
          [{:entity_tag, tag} | acc]
        end

      {:last_modified, raw}, acc when is_binary(raw) ->
        last_modified =
          raw
          |> :cow_date.parse_date()
          |> NaiveDateTime.from_erl!()
          |> DateTime.from_naive!("Etc/UTC")

        [{:last_modified, last_modified} | acc]

      _, acc ->
        acc
    end)
  end

  def short_circuit!(%Plug.Conn{private: private} = conn, cont) do
    case Access.get(private, :frugality_metadata) do
      {:derived, metadata} ->
        result =
          conn
          |> Conditions.from_conn()
          |> Conditions.evaluate(metadata)

        case result do
          :ok ->
            cont.(conn)

          status ->
            send_resp(conn, status, "")
        end

      :auto ->
        raise ArgumentError, "can not short circuit an automatic validators derivation"

      _ ->
        raise ArgumentError, "invalid metadata"
    end
  end
end
