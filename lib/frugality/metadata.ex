defmodule Frugality.Metadata do
  alias Frugality.Core.EntityTag

  @callback entity_tag(any()) :: String.t() | nil
  @callback last_modified(any()) :: DateTime.t() | nil

  defmacro __using__(_) do
    quote do
      @behaviour Frugality.Metadata

      @impl Frugality.Metadata
      def entity_tag(_), do: nil

      @impl Frugality.Metadata
      def last_modified(_), do: nil

      defoverridable Frugality.Metadata

      def encode(term) do
        Frugality.Metadata.encode(term)
      end

      def derive(data) do
        Frugality.Metadata.derive(__MODULE__, data)
      end
    end
  end

  def encode(term) do
    term
    |> then(&:crypto.hash(:md5, &1))
    |> Base.encode16()
  end

  def derive(module, data) do
    case {module.entity_tag(data), module.last_modified(data)} do
      {nil, nil} ->
        []

      {etag, nil} ->
        [entity_tag: EntityTag.to_string({:weak, etag})]

      {nil, lm} ->
        [last_modified: serialize_date(lm)]

      {etag, lm} ->
        [
          entity_tag: EntityTag.to_string({:weak, etag}),
          last_modified: serialize_date(lm)
        ]
    end
  end

  defp serialize_date(%DateTime{} = dt) do
    dt
    |> DateTime.to_naive()
    |> NaiveDateTime.to_erl()
    |> :cow_date.rfc1123()
  end
end
