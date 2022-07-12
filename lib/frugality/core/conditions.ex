defmodule Frugality.Core.Condition do
  alias Frugality.Core.EntityTagSet
  alias Frugality.Core.Metadata

  @type t ::
          {:if_match | :if_none_match, EntityTagSet.t()}
          | {:if_unmodified_since | :if_modified_since, DateTime.t()}

  @spec matches?(t(), Metadata.t()) :: {atom(), boolean()}
  def matches?({:if_match = c, _}, %Metadata{entity_tag: nil}), do: {c, false}
  def matches?({:if_match = c, :any}, _), do: {c, true}

  def matches?({:if_match = c, tags}, %Metadata{entity_tag: tag}),
    do: {c, EntityTagSet.matches_weak?(tags, tag)}

  def matches?({:if_none_match = c, _}, %Metadata{entity_tag: nil}), do: {c, true}
  def matches?({:if_none_match = c, :any}, _), do: {c, false}

  def matches?({:if_none_match = c, tags}, %Metadata{entity_tag: tag}),
    do: {c, !EntityTagSet.matches_weak?(tags, tag)}

  def matches?({:if_unmodified_since = c, _}, %Metadata{last_modified: nil}), do: {c, false}

  def matches?({:if_unmodified_since = c, iums}, %Metadata{last_modified: lm}),
    do: {c, DateTime.compare(lm, iums) in [:lt, :eq]}

  def matches?({:if_modified_since = c, _}, %Metadata{last_modified: nil}), do: {c, false}

  def matches?({:if_modified_since = c, ims}, %Metadata{last_modified: lm}),
    do: {c, DateTime.compare(lm, ims) == :gt}
end

defmodule Frugality.Conditions do
  alias Frugality.Condition
  alias Frugality.EntityTagSet
  alias Frugality.Metadata

  @type result :: :ok | :precondition_failed | :not_modified

  @type t :: %__MODULE__{
          method: String.t(),
          conditions: Enum.t()
        }

  defstruct [:method, conditions: []]

  def from_conn(%Plug.Conn{method: method} = conn) do
    # `if-modified-since` is evaluated only when the method is GET or HEAD so it
    # can be skipped otherwise.
    if_modified_since =
      if method in ["GET", "HEAD"] do
        ["if-modified-since"]
      else
        []
      end

    conditions_stream =
      [
        "if-match",
        "if-unmodified-since",
        "if-none-match"
        | if_modified_since
      ]
      |> Stream.map(&get_req_header_pair(conn, &1))
      |> Stream.map(&into_req_condition/1)
      |> Stream.transform([], &filter_by_precedence/2)

    %__MODULE__{method: method, conditions: conditions_stream}
  end

  defp filter_by_precedence(nil, acc), do: {[], acc}

  defp filter_by_precedence({:if_unmodified_since, _}, [_ | _] = acc), do: {[], acc}

  defp filter_by_precedence({:if_modified_since, _}, [{:if_none_match, _} | _] = acc),
    do: {[], acc}

  defp filter_by_precedence(header, acc), do: {[header], [header | acc]}

  defp get_req_header_pair(%Plug.Conn{} = conn, header) do
    {header, Plug.Conn.get_req_header(conn, header)}
  end

  defp into_req_condition({_, []}), do: nil

  defp into_req_condition({"if-match", values}) do
    values
    |> Enum.join(", ")
    |> then(&{:if_match, EntityTagSet.from_string(&1)})
  end

  defp into_req_condition({"if-none-match", values}) do
    values
    |> Enum.join(", ")
    |> then(&{:if_none_match, EntityTagSet.from_string(&1)})
  end

  defp into_req_condition({"if-modified-since", [value | _]}) do
    value
    |> to_datetime()
    |> then(&{:if_modified_since, &1})
  end

  defp into_req_condition({"if-unmodified-since", [value | _]}) do
    value
    |> to_datetime()
    |> then(&{:if_modified_since, &1})
  end

  @spec evaluate(t(), Metadata.t()) :: result()
  def evaluate(%__MODULE__{method: method, conditions: conditions}, %Metadata{} = metadata) do
    conditions
    |> Stream.map(&Condition.matches?(&1, metadata))
    |> Enum.reduce_while(:ok, &determine_status(method, &1, &2))
  end

  defp determine_status(method, {:if_none_match, false}, _) when method in ["GET", "HEAD"],
    do: {:halt, :not_modified}

  defp determine_status(_, {:if_modified_since, false}, _),
    do: {:halt, :not_modified}

  defp determine_status(_, {_, false}, _), do: {:halt, :precondition_failed}

  defp determine_status(_, _, acc), do: {:cont, acc}

  defp to_datetime(http_date) when is_binary(http_date) do
    http_date
    |> :cow_http_hd.parse_if_modified_since()
    |> NaiveDateTime.from_erl!()
    |> DateTime.from_naive!("Etc/UTC")
  end
end
