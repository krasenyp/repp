defmodule ReppWeb.BookController do
  use ReppWeb, :controller
  use Frugality

  alias Repp.Books
  alias Repp.Books.Book

  plug :put_generator, ReppWeb.BookMetadata

  action_fallback ReppWeb.FallbackController

  def index(conn, _params) do
    books = Books.list_books()

    conn
    |> derive_metadata(books: books)
    |> short_circuit!(fn conn ->
      conn
      |> cache_for(60)
      |> render("index.json", books: books)
    end)
  end

  def create(conn, %{"book" => book_params}) do
    with {:ok, %Book{} = book} <- Books.create_book(book_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.book_path(conn, :show, book))
      |> render("show.json", book: book)
    end
  end

  def show(conn, %{"id" => id}) do
    book = Books.get_book!(id)

    conn
    |> cache_for(60)
    |> render("show.json", book: book)
  end

  def update(conn, %{"id" => id, "book" => book_params}) do
    book = Books.get_book!(id)

    with {:ok, %Book{} = book} <- Books.update_book(book, book_params) do
      render(conn, "show.json", book: book)
    end
  end

  def delete(conn, %{"id" => id}) do
    book = Books.get_book!(id)

    with {:ok, %Book{}} <- Books.delete_book(book) do
      send_resp(conn, :no_content, "")
    end
  end

  defp cache_for(conn, seconds), do: put_cache_control(conn, "public, max-age=#{seconds}")

  defp put_cache_control(conn, cc), do: put_resp_header(conn, "cache-control", cc)
end
