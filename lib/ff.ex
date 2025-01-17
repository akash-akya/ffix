defmodule FF do
  alias FF.FilterGraph
  alias FF.Runner

  # ffmpeg -v warning -y -i pipe:0 -t 5 -filter_complex "drawtext=text='HELLO THERE':y=500:x=400:fontsize=200:fontfile=/usr/share/fonts/truetype/freefont/FreeSerif.ttf" -f mp4 -movflags empty_moov -

  def run(filtergraph, inputs) do
    {:ok, {graph, [output_pad]}} = FilterGraph.to_filtergraph(filtergraph)

    [
      ~W(ffmpeg -v warning -y -t 5),
      Enum.map(inputs, &["-i", &1]),
      ["-filter_complex", graph],
      ["-map", output_pad],
      ~W(-f mp4 -movflags empty_moov -)
    ]
    |> List.flatten()
    |> Runner.run()
  end
end
