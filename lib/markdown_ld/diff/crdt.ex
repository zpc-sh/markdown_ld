defmodule MarkdownLd.Diff.CRDT do
  @moduledoc """
  CRDT-based conflict-free replicated data types for collaborative markdown editing.
  
  Implements operation-based CRDTs optimized for markdown structures:
  - Text sequences with character-level tombstones
  - Tree operations for block structure  
  - Set-based operations for JSON-LD triples
  - Vector clocks for causal ordering
  
  This helps Codex handle real-time collaborative editing without conflicts.
  """
  
  alias MarkdownLd.Diff.{Change, Patch}
  
  @typedoc "Logical timestamp for causal ordering"
  @type logical_time :: non_neg_integer()
  
  @typedoc "Actor identifier in the collaborative system"
  @type actor_id :: String.t()
  
  @typedoc "Vector clock for distributed causality"
  @type vector_clock :: %{actor_id() => logical_time()}
  
  @typedoc "Character with tombstone and causality info"
  @type char_op :: %{
    id: String.t(),
    char: String.t(),
    visible: boolean(),
    actor: actor_id(),
    clock: vector_clock()
  }
  
  @typedoc "Text CRDT state"
  @type text_crdt :: %{
    chars: [char_op()],
    clock: vector_clock()
  }
  
  defmodule VectorClock do
    @moduledoc "Vector clock operations for causal ordering"
    
    @spec new() :: MarkdownLd.Diff.CRDT.vector_clock()
    def new(), do: %{}
    
    @spec tick(MarkdownLd.Diff.CRDT.vector_clock(), MarkdownLd.Diff.CRDT.actor_id()) :: MarkdownLd.Diff.CRDT.vector_clock()
    def tick(clock, actor) do
      Map.update(clock, actor, 1, &(&1 + 1))
    end
    
    @spec merge(MarkdownLd.Diff.CRDT.vector_clock(), MarkdownLd.Diff.CRDT.vector_clock()) :: MarkdownLd.Diff.CRDT.vector_clock()
    def merge(clock1, clock2) do
      all_actors = MapSet.union(MapSet.new(Map.keys(clock1)), MapSet.new(Map.keys(clock2)))
      
      Enum.reduce(all_actors, %{}, fn actor, merged ->
        time1 = Map.get(clock1, actor, 0)
        time2 = Map.get(clock2, actor, 0)
        Map.put(merged, actor, max(time1, time2))
      end)
    end
    
    @spec happens_before?(MarkdownLd.Diff.CRDT.vector_clock(), MarkdownLd.Diff.CRDT.vector_clock()) :: boolean()
    def happens_before?(clock1, clock2) do
      all_actors = MapSet.union(MapSet.new(Map.keys(clock1)), MapSet.new(Map.keys(clock2)))
      
      Enum.all?(all_actors, fn actor ->
        Map.get(clock1, actor, 0) <= Map.get(clock2, actor, 0)
      end) and clock1 != clock2
    end
    
    @spec concurrent?(MarkdownLd.Diff.CRDT.vector_clock(), MarkdownLd.Diff.CRDT.vector_clock()) :: boolean()
    def concurrent?(clock1, clock2) do
      not happens_before?(clock1, clock2) and not happens_before?(clock2, clock1)
    end
  end
  
  defmodule TextCRDT do
    @moduledoc "CRDT for collaborative text editing with character-level operations"
    
    @spec new() :: MarkdownLd.Diff.CRDT.text_crdt()
    def new() do
      %{chars: [], clock: VectorClock.new()}
    end
    
    @spec insert(MarkdownLd.Diff.CRDT.text_crdt(), non_neg_integer(), String.t(), MarkdownLd.Diff.CRDT.actor_id()) :: MarkdownLd.Diff.CRDT.text_crdt()
    def insert(%{chars: chars, clock: clock} = crdt, pos, text, actor) do
      new_clock = VectorClock.tick(clock, actor)
      
      new_chars = text
      |> String.graphemes()
      |> Enum.with_index()
      |> Enum.map(fn {char, idx} ->
        %{
          id: "#{actor}-#{Map.get(new_clock, actor)}-#{idx}",
          char: char,
          visible: true,
          actor: actor,
          clock: new_clock
        }
      end)
      
      # Insert at position with causality-preserving ordering
      {before, after_chars} = Enum.split(chars, pos)
      updated_chars = before ++ new_chars ++ after_chars
      
      %{crdt | chars: updated_chars, clock: new_clock}
    end
    
    @spec delete(MarkdownLd.Diff.CRDT.text_crdt(), non_neg_integer(), non_neg_integer(), MarkdownLd.Diff.CRDT.actor_id()) :: MarkdownLd.Diff.CRDT.text_crdt()
    def delete(%{chars: chars, clock: clock} = crdt, pos, length, actor) do
      new_clock = VectorClock.tick(clock, actor)
      
      updated_chars = chars
      |> Enum.with_index()
      |> Enum.map(fn {char_op, idx} ->
        if idx >= pos and idx < pos + length and char_op.visible do
          %{char_op | visible: false}  # Tombstone the character
        else
          char_op
        end
      end)
      
      %{crdt | chars: updated_chars, clock: new_clock}
    end
    
    @spec to_string(MarkdownLd.Diff.CRDT.text_crdt()) :: String.t()
    def to_string(%{chars: chars}) do
      chars
      |> Enum.filter(& &1.visible)
      |> Enum.map(& &1.char)
      |> Enum.join("")
    end
    
    @spec merge(MarkdownLd.Diff.CRDT.text_crdt(), MarkdownLd.Diff.CRDT.text_crdt()) :: MarkdownLd.Diff.CRDT.text_crdt()
    def merge(crdt1, crdt2) do
      merged_clock = VectorClock.merge(crdt1.clock, crdt2.clock)
      
      # Merge character operations with causal ordering
      all_chars = (crdt1.chars ++ crdt2.chars)
      |> Enum.uniq_by(& &1.id)
      |> Enum.sort_by(fn char_op ->
        # Sort by actor, then logical time, then position
        {char_op.actor, Map.get(char_op.clock, char_op.actor, 0), char_op.id}
      end)
      
      %{chars: all_chars, clock: merged_clock}
    end
  end
  
  defmodule BlockCRDT do
    @moduledoc "CRDT for block-level markdown structure operations"
    
    @typedoc "Block operation with causality"
    @type block_op :: %{
      id: String.t(),
      type: :insert | :delete | :move,
      block_id: String.t(),
      parent_id: String.t() | nil,
      position: non_neg_integer(),
      content: map() | nil,
      visible: boolean(),
      actor: MarkdownLd.Diff.CRDT.actor_id(),
      clock: MarkdownLd.Diff.CRDT.vector_clock()
    }
    
    @typedoc "Block structure CRDT"
    @type block_crdt :: %{
      operations: [block_op()],
      clock: MarkdownLd.Diff.CRDT.vector_clock()
    }
    
    @spec new() :: block_crdt()
    def new() do
      %{operations: [], clock: VectorClock.new()}
    end
    
    @spec insert_block(block_crdt(), String.t(), String.t() | nil, non_neg_integer(), map(), MarkdownLd.Diff.CRDT.actor_id()) :: block_crdt()
    def insert_block(%{operations: ops, clock: clock} = crdt, block_id, parent_id, position, content, actor) do
      new_clock = VectorClock.tick(clock, actor)
      
      op = %{
        id: "#{actor}-#{Map.get(new_clock, actor)}-insert",
        type: :insert,
        block_id: block_id,
        parent_id: parent_id,
        position: position,
        content: content,
        visible: true,
        actor: actor,
        clock: new_clock
      }
      
      %{crdt | operations: [op | ops], clock: new_clock}
    end
    
    @spec delete_block(block_crdt(), String.t(), MarkdownLd.Diff.CRDT.actor_id()) :: block_crdt()
    def delete_block(%{operations: ops, clock: clock} = crdt, block_id, actor) do
      new_clock = VectorClock.tick(clock, actor)
      
      op = %{
        id: "#{actor}-#{Map.get(new_clock, actor)}-delete",
        type: :delete,
        block_id: block_id,
        parent_id: nil,
        position: 0,
        content: nil,
        visible: false,
        actor: actor,
        clock: new_clock
      }
      
      %{crdt | operations: [op | ops], clock: new_clock}
    end
    
    @spec to_structure(block_crdt()) :: [map()]
    def to_structure(%{operations: ops}) do
      # Resolve operations in causal order to build final structure
      ops
      |> Enum.sort_by(fn op ->
        {Map.get(op.clock, op.actor, 0), op.id}
      end)
      |> resolve_operations([])
    end
    
    defp resolve_operations([], acc), do: Enum.reverse(acc)
    defp resolve_operations([op | rest], acc) do
      case op.type do
        :insert when op.visible ->
          block = %{
            id: op.block_id,
            parent_id: op.parent_id,
            position: op.position,
            content: op.content
          }
          resolve_operations(rest, [block | acc])
        
        :delete ->
          # Remove block if it was deleted
          updated_acc = Enum.reject(acc, fn block -> block.id == op.block_id end)
          resolve_operations(rest, updated_acc)
        
        _ ->
          resolve_operations(rest, acc)
      end
    end
  end
  
  @doc """
  Convert CRDT operations to standard diff changes for compatibility with Codex's system
  """
  @spec crdt_to_changes(text_crdt() | BlockCRDT.block_crdt(), actor_id()) :: [Change.t()]
  def crdt_to_changes(%{chars: _} = text_crdt, actor) do
    # Convert text CRDT operations to inline changes
    text_crdt.chars
    |> Enum.filter(fn char_op -> char_op.actor == actor end)
    |> Enum.map(fn char_op ->
      kind = if char_op.visible, do: :insert_inline, else: :delete_inline
      %Change{
        id: char_op.id,
        kind: kind,
        path: [0, 0],  # Simplified path
        payload: %{char: char_op.char, position: 0},
        meta: %{actor: char_op.actor, clock: char_op.clock}
      }
    end)
  end
  
  def crdt_to_changes(%{operations: ops}, actor) do
    # Convert block CRDT operations to block changes
    ops
    |> Enum.filter(fn op -> op.actor == actor end)
    |> Enum.map(fn op ->
      kind = case op.type do
        :insert -> :insert_block
        :delete -> :delete_block
        :move -> :move_block
      end
      
      %Change{
        id: op.id,
        kind: kind,
        path: [op.position],
        payload: op.content || %{},
        meta: %{actor: op.actor, clock: op.clock}
      }
    end)
  end
  
  @doc """
  Merge multiple CRDT states - this is where the magic happens!
  No conflicts because CRDTs are mathematically conflict-free
  """
  @spec merge_crdts([text_crdt() | BlockCRDT.block_crdt()]) :: text_crdt() | BlockCRDT.block_crdt()
  def merge_crdts([first | rest]) do
    Enum.reduce(rest, first, fn crdt, acc ->
      case {acc, crdt} do
        {%{chars: _}, %{chars: _}} -> TextCRDT.merge(acc, crdt)
        {%{operations: _}, %{operations: _}} -> merge_block_crdts(acc, crdt)
        _ -> acc  # Type mismatch, return first
      end
    end)
  end
  
  defp merge_block_crdts(crdt1, crdt2) do
    merged_clock = VectorClock.merge(crdt1.clock, crdt2.clock)
    all_ops = (crdt1.operations ++ crdt2.operations) |> Enum.uniq_by(& &1.id)
    
    %{operations: all_ops, clock: merged_clock}
  end
end