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
          kind: :input | :filter,
          name: atom() | String.t(),
          instance: String.t() | atom() | nil,
          input_ref: InputRef.t() | nil,
          inputs: [Ref.t()],
          args: [arg()],
          output_media: [FFix.Graph.StreamRef.media()],
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
    output_media: [:unknown],
    metadata: %{}
  ]

  @spec sink?(term()) :: boolean()
  def sink?(node), do: match?(%__MODULE__{kind: :filter, output_media: []}, node)
end
