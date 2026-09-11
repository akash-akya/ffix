defmodule FFix.Graph.Node do
  @moduledoc false

  alias FFix.Graph
  alias FFix.Graph.InputRef
  alias FFix.Graph.Ref

  @type arg_key :: atom() | String.t() | :pos

  @type arg_value ::
          nil
          | boolean()
          | integer()
          | float()
          | String.t()
          | atom()
          | [arg_value()]

  @type arg :: {arg_key(), arg_value()}

  @type t :: %__MODULE__{
          id: Graph.node_id(),
          identity: reference(),
          kind: :input | :filter,
          name: atom() | String.t(),
          instance: String.t() | atom() | nil,
          input_ref: InputRef.t() | nil,
          inputs: [Ref.t()],
          args: [arg()],
          outputs: non_neg_integer(),
          output_media: [FFix.Graph.StreamRef.media()],
          media: FFix.Graph.StreamRef.media(),
          metadata: map()
        }

  defstruct [
    :id,
    :identity,
    :kind,
    :name,
    :instance,
    :input_ref,
    inputs: [],
    args: [],
    outputs: 1,
    output_media: [:unknown],
    media: :unknown,
    metadata: %{}
  ]
end
