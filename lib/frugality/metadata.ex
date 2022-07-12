defmodule Frugality.Metadata do
  @behaviour Plug

  defmacro __using__([]) do
    quote do
      import Frugality

      plug Frugality.Metadata
    end
  end

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(%Plug.Conn{} = conn, _) do
    Plug.Conn.register_before_send(conn, &apply_validators/1)
  end

  defp apply_validators(%Plug.Conn{private: private} = conn) do
    private
    |> Access.get(:frugality_metadata)
    |> then(fn
      {:derived, metadata} ->
        metadata

      _ ->
        Metadata.new([])
    end)
    |> Metadata.to_headers()
    |> then(&Plug.Conn.merge_resp_headers(conn, &1))
  end
end
