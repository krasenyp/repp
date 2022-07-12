defmodule Frugality do
  alias Frugality.Core.Conditions
  alias Frugality.Core.Metadata

  import Plug.Conn

  def derive_metadata(%Plug.Conn{} = conn) do
    conn
    |> put_private(:frugality_metadata, :auto)
    |> register_before_send(&derive_from_resp_body/1)
  end

  def derive_metadata(%Plug.Conn{} = conn, generator, data) do
    metadata =
      data
      |> Enum.into(%{})
      |> Map.put(:conn, conn)
      |> generator.derive()

    put_metadata(conn, metadata)
  end

  def put_metadata(%Plug.Conn{} = conn, %Metadata{} = metadata) do
    put_private(conn, :frugality_metadata, {:derived, metadata})
  end

  defp derive_from_resp_body(%Plug.Conn{status: 200, method: method, private: private} = conn)
       when method in ["GET", "HEAD"] do
    case Access.get(private, :frugality_metadata) do
      :auto ->
        entity_tag =
          conn.resp_body
          |> then(&:crypto.hash(:md5, &1))
          |> Base.encode16()

        metadata = Metadata.new(entity_tag: {:weak, entity_tag})

        result =
          conn
          |> Conditions.from_conn()
          |> Conditions.evaluate(metadata)

        case result do
          :ok ->
            put_metadata(conn, metadata)

          status ->
            resp(conn, status, "")
        end

      _ ->
        conn
    end
  end

  defp derive_from_resp_body(conn), do: conn
end
