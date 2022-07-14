defmodule ReppWeb.BookMetadata do
  use Frugality.Metadata

  def entity_tag(%{books: books}) do
    books
    |> Enum.map(fn %{id: id, title: title, updated_at: updated_at} ->
      [id, title, updated_at]
    end)
    |> then(&["books" | &1])
    |> encode()
  end
end
