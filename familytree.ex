defmodule DefineEdge do
  import Graph
  import Keyword
  @base_inverses [parent: :child]

  # @spec mirror_kwlist(keyword) :: keyword
  def mirror_kwlist(kwlist) do
    # If we have [a:b, c:d] returns a mirrored list [b:a, d:c]
    for {k, v} <- kwlist do
      {v, k}
    end
  end

  # @spec inverses() :: keyword
  def inverses do
    merge(@base_inverses, mirror_kwlist(@base_inverses))
  end

  # Expands acceptable syntax

  @type expr :: {atom, atom, atom}

  # @spec new_relationships(expr) :: Graph.t()
  def new_relationship({primitive, v1, v2}, tree) do
    tree = add_edge(tree, v1, v2, label: primitive)
    # If not in inverse, return itself
    inverse = Keyword.get(inverses(), primitive, primitive)
    add_edge(tree, v2, v1, label: inverse)
  end
end

defmodule QueryTree do
  import Graph
  import Enum

  # @spec make_pairs(nonempty_list) :: [list]
  def make_pairs([]) do nil end

  def make_pairs(lst) do
    # Make a list [a b c d] into [a|b] [b|c] [c|d]. So a list of vertices to a list of edges, basically
    chunk_every(lst, 2, 1, :discard)
  end


  @type expr :: {atom, atom}

  # @spec query(expr) :: [{atom}]
  def query({v1, v2}, tree) do
    # List of vertex structs
    vertices = get_shortest_path(tree, v1, v2)
    pairs = make_pairs(vertices) # FIXME
    edges = map(pairs, fn [v1, v2] -> edges(tree, v1, v2) end)

    labels = map(map(edges, &hd/1), fn x -> x.label end)

    breadcrumbed =
      map(map(edges, &hd/1), fn x ->
        %Graph.Edge{label: l, v2: v} = x
        # EG: {:child, :vader}
        {l, v}
      end)

   # breadcrumbed
    Simplifier.collapse_compounds(breadcrumbed)
  end
end

defmodule GraphState do
  @name __MODULE__
  def new do
    Agent.start_link(fn -> Graph.new() end, name: @name)
  end

  def query(pid, expr) do
    Agent.get(@name, &QueryTree.query(expr, &1))
  end

  def add_edge(pid, expr) do
    Agent.update(@name, &DefineEdge.new_relationship(expr, &1))
    expr
  end
end

defmodule Interpreter do
  import String
  import Enum
  import GraphState

def parse(str) do
  # Return a list of atoms based on processing/validating/whatever a quoted form.
  map(split(str), &to_atom/1)
end

def handle([relationship, v1, v2]) do
  # DefineEdge.new_relationship({relationship, v1, v2})
  &add_edge(&1, {relationship, v1, v2})
end

def handle([v1, v2]) do
  &query(&1, {v1, v2})
end
end

defmodule Interaction do
  import Interpreter
  import GraphState
  def main() do
    familytree= GraphState.new()
    repl(familytree)

  end


  def repl(tree, prompt \\ ">") do
    command = IO.gets(prompt)
    if command == :exit do
      nil
    else
      result = Interpreter.handle(parse(command)).(tree)
      IO.inspect(result)
      repl(tree, prompt)
    end
  end
end

defmodule Simplifier do
  import Enum
  import List
  @compound_relationships %{
    [:parent, :parent] => :grandparent,
    [:sibling, :sibling] => :sibling
  }

  def collapse([], _, _) do
    []
  end

  def collapse(list, sublist, replacement) do
    if List.starts_with?(list, sublist) do
      replacement ++ collapse(Enum.slice(list, length(sublist), length(list)), sublist, replacement)
    else
      [hd(list) | collapse(tl(list), sublist, replacement)]
    end
  end

  defp helper(lst, sorted, compounds \\ @compound_relationships)
  defp helper(lst, [h | t], compounds) do
    helper(collapse(lst, h, compounds[h]), t, compounds)
  end

  defp helper(lst, [], _compounds) do
    lst
  end

  def collapse_compounds(list, compounds \\ @compound_relationships) do
    sorted = Enum.sort(Map.keys(compounds), fn x,y -> length(x)< length(y) end)
    helper(list, sorted)
  end

end
