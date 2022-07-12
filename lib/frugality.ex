defmodule Frugality do
  alias Frugality.Conditions
  alias Frugality.Metadata

  import Plug.Conn

  def derive_metadata(%Plug.Conn{} = conn) do
    register_before_send(conn, fn
      %Plug.Conn{status: 200, method: method} = conn when method in ["GET", "HEAD"] ->
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
            merge_resp_headers(conn, Metadata.to_headers(metadata))

          status ->
            resp(conn, status, "")
        end

      conn ->
        conn
    end)
  end
end
