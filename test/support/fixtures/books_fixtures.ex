defmodule Repp.BooksFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Repp.Books` context.
  """

  @doc """
  Generate a book.
  """
  def book_fixture(attrs \\ %{}) do
    {:ok, book} =
      attrs
      |> Enum.into(%{
        title: "some title"
      })
      |> Repp.Books.create_book()

    book
  end
end
