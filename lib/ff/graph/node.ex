defmodule FF.Graph.Node do
  @moduledoc """
  A single input or filter node inside a canonical filtergraph.
  """

  alias FF.Expr
  alias FF.Graph
  alias FF.Graph.InputRef
  alias FF.Graph.Ref

  @type arg_key :: atom() | String.t() | :pos

  @type arg_value ::
          nil
          | boolean()
          | integer()
          | float()
          | String.t()
          | atom()
          | Expr.t()
          | [arg_value()]

  @type arg :: {arg_key(), arg_value()}

  @type t :: %__MODULE__{
          id: Graph.node_id(),
          kind: :input | :filter,
          name: atom(),
          instance: String.t() | atom() | nil,
          input_ref: InputRef.t() | nil,
          inputs: [Ref.t()],
          args: [arg()],
          outputs: non_neg_integer(),
          media: :audio | :video | :unknown,
          metadata: map()
        }

  defstruct [
    :id,
    :kind,
    :name,
    :instance,
    :input_ref,
    inputs: [],
    args: [],
    outputs: 1,
    media: :unknown,
    metadata: %{}
  ]
end
