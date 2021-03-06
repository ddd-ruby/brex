defmodule Brex.Operator do
  @moduledoc """
  Contains the `Aggregatable` root protocol for operators, provides some helpers
  for Operators and is `use`able to define ...

  # Custom Operators

  **TL;DR**

  1. `use Brex.Operator`
  2. define a struct with a `clauses` key (`defstruct [:clauses]`)
  3. define an `aggregator/1` function and return the aggregating function

  There are various `use` options to control this behaviour and to make your
  life easier.

  ## Options
  ### `aggregator`

  This controls the aggregator definition, it can receive:

  - a function reference: `&Enum.all?/1`
  - an anonymous function: `&Enum.all(&1)` or `fn v -> Enum.all(v) end`
  - an atom, identifying a function in this module: `:my_aggregator`
  - a tuple, identifying a function in a module: `{MyModule, :my_aggregator}`

  ### `clauses`

  Allows to override the expected default key (`clauses`) for contained
  "sub-rules".

  # How does this magic work?

  Brex operators are based on the `Brex.Operator.Aggregatable` protocol. When
  calling `use Brex.Operator` Brex tries to define a number of functions for you
  which it then uses to implement the protocol. The protocol calls then simply
  delegate to the functions in your custom operator module.

  Furthermore it defines an `evaluate/2` function which is necessary to actually
  use this operator as a Brex rule. This might change in the future, to make
  implementing the `Aggregatable` protocol sufficient for defining custom operators.

  To do all of this it calls the `Brex.Operator.Builder.build_from_use/1`
  function, which does a number of things.

  1. it defines an `aggregator/1` function, if an `aggregator` option has been given
  2. it defines a `clauses/1` function, which extracts the clauses from the struct
  3. it defines a `new/2` function, which news an operator with some clauses

  After that it tries to define the implementation of the `Aggregatable`
  protocol, which simply delegates it's calls to the using module.

  Due to that it checks if the necessary functions (`aggregator/1` and
  `clauses/1`) exist. In case they don't exist, a `CompileError` is being raised.
  """

  alias Brex.Types

  # A struct implementing this behaviour
  @type t :: struct()

  @type clauses :: list(Types.rule())

  defprotocol Aggregatable do
    @type clauses :: list(Brex.Types.rule())

    @spec aggregator(t()) :: (list(boolean()) -> boolean())
    def aggregator(aggregatable)

    @spec clauses(t()) :: clauses()
    def clauses(aggregatable)

    @spec new(t(), clauses()) :: t()
    def new(aggregatable, clauses)
  end

  defmacro __using__(opts) do
    Brex.Operator.Builder.build_from_use(opts)
  end

  @spec default_operators() :: list(module())
  def default_operators do
    [
      Brex.Operator.All,
      Brex.Operator.Any,
      Brex.Operator.None
    ]
  end

  @doc """
  Returns a new instance of an operator; not meant to be used directly but is
  instead used internally when calling the operator shortcut functions on `Brex`.
  """
  @spec new(operator :: module(), rules :: clauses()) :: t()
  def new(operator, rules) do
    operator
    |> struct()
    |> Aggregatable.new(rules)
  end

  @doc """
  Returns the rules contained in the Operator. Raises a `Protocol.UndefinedError`
  if the given value does not implement `Brex.Operator.Aggregatable`.

  ## Examples

      iex> Brex.Operator.clauses!(Brex.all([&is_list/1, &is_map/1]))
      [&is_list/1, &is_map/1]
  """
  @spec clauses!(t()) :: clauses()
  defdelegate clauses!(operator), to: Aggregatable, as: :clauses

  @doc """
  Returns `{:ok, list(t())}` if the rule implements Brex.Operator.Aggregatable
  and `:error` otherwise.

  ## Examples

      iex> Brex.Operator.clauses(Brex.all([&is_list/1, &is_map/1]))
      {:ok, [&is_list/1, &is_map/1]}

      iex> Brex.Operator.clauses(&is_list/1)
      :error

      iex> Brex.Operator.clauses("foo_bar")
      :error
  """
  @spec clauses(t()) :: {:ok, clauses()} | :error
  def clauses(operator) do
    case Aggregatable.impl_for(operator) do
      nil -> :error
      impl -> {:ok, impl.clauses(operator)}
    end
  end
end
