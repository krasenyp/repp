defmodule Frugality.Plug do
  @behaviour Plug

  alias Frugality.Core.Conditions
  alias Frugality.Core.Metadata

  import Plug.Conn

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(%Plug.Conn{} = conn, _) do
    conn
    |> put_private(:frugality_metadata, :auto)
    |> register_before_send(&apply_validators/1)
  end

  defp apply_validators(%Plug.Conn{method: method, status: 200, private: private} = conn)
       when method in ["GET", "HEAD"] do
    case Access.get(private, :frugality_metadata) do
      :auto ->
        conn
        |> derive_from_resp_body()
        |> apply_validators()

      {:derived, metadata} ->
        headers = Metadata.to_headers(metadata)

        merge_resp_headers(conn, headers)

      _ ->
        conn
    end
  end

  defp derive_from_resp_body(%Plug.Conn{resp_body: resp_body} = conn) do
    entity_tag =
      resp_body
      |> then(&:crypto.hash(:md5, &1))
      |> Base.encode16()

    metadata = Metadata.new(entity_tag: {:weak, entity_tag})

    result =
      conn
      |> Conditions.from_conn()
      |> Conditions.evaluate(metadata)

    case result do
      :ok ->
        Frugality.put_metadata(conn, metadata)

      status ->
        resp(conn, status, "")
    end
  end

  defp derive_from_resp_body(conn), do: conn
end
