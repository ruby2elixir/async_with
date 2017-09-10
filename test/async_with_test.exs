defmodule AsyncWithTest do
  use ExUnit.Case, async: true
  use AsyncWith

  @async_with_timeout 50

  defp delay(delay, value) do
    :timer.sleep(delay)
    value
  end

  defp echo(value) do
    {:ok, value}
  end

  defp get_true(_value \\ nil) do
    true
  end

  defp error(_value \\ nil) do
    :error
  end

  defp raise_oops(_value \\ nil) do
    raise("oops")
  end

  defp delayed_raise_oops(delay, _value) do
    :timer.sleep(delay)
    raise_oops()
  end

  defp pid(_value \\ nil) do
    {:ok, self()}
  end

  defp pid_registry(agent, registry_name) do
    pid = self()
    Agent.update(agent, &Map.merge(&1, %{registry_name => pid}))
    :ok
  end

  doctest AsyncWith

  test "raises an ArgumentError error if 'async' is not followed by 'with'" do
    assert_raise(ArgumentError, ~s("async" macro must be used with "with"), fn ->
      ast = quote do
        async a <- 1 do
          2
        end
      end

      Macro.expand(ast, __ENV__)
    end)
  end

  test "works without clauses" do
    result =
      async with do
        1
      end

    assert result == 1
  end

  test "works with one clause" do
    result =
      async with {:ok, a} <- echo("a") do
        a
      end

    assert result == "a"
  end

  test "works with several clauses" do
    result =
      async with {:ok, a} <- echo("a"),
                 {:ok, b} <- echo("b"),
                 {:ok, c} <- echo("c"),
                 {:ok, d} <- echo("d"),
                 {:ok, e} <- echo("e"),
                 {:ok, f} <- echo("f"),
                 {:ok, g} <- echo("g") do
        Enum.join([a, b, c, d, e, f, g], " ")
      end

    assert result == "a b c d e f g"
  end

  test "works with clauses that depend on variables binded in previous clauses" do
    result =
      async with {:ok, a} <- echo("a"),
                 b = "b",
                 {:ok, c} <- echo("c(#{a})"),
                 {:ok, d} <- echo("d"),
                 {:ok, e} <- echo("e(#{a})"),
                 {:ok, f} <- echo("f(#{e}, #{d})"),
                 {:ok, g} <- echo("g(#{e})"),
                 {:ok, h} <- echo("h(#{f})"),
                 i = "i",
                 {:ok, j} <- echo("j(#{h}, #{i})") do
        Enum.join([a, b, c, d, e, f, g, h, i, j], " ")
      end

    assert result == "a b c(a) d e(a) f(e(a), d) g(e(a)) h(f(e(a), d)) i j(h(f(e(a), d)), i)"
  end

  test "works with clauses that reference external variables" do
    a = "a"
    b = "b"

    result =
      async with {:ok, c} <- echo("c(#{a})"),
                 {:ok, d} <- echo("d"),
                 {:ok, e} <- echo("e(#{a})"),
                 {:ok, f} <- echo("f(#{e}, #{d})"),
                 {:ok, g} <- echo("g(#{e})"),
                 {:ok, h} <- echo("h(#{f})"),
                 {:ok, i} <- echo("i"),
                 {:ok, j} <- echo("j(#{h}, #{i})") do
        Enum.join([a, b, c, d, e, f, g, h, i, j], " ")
      end

    assert result == "a b c(a) d e(a) f(e(a), d) g(e(a)) h(f(e(a), d)) i j(h(f(e(a), d)), i)"
  end

  test "works with clauses with pin matching" do
    ok = :ok
    e = "e(a)"

    result =
      async with {:ok, a} <- echo("a"),
                 b = "b",
                 {:ok, c} <- echo("c(#{a})"),
                 {^ok, d} <- echo("d"),
                 {:ok, ^e} <- echo("e(#{a})"),
                 {:ok, f} <- echo("f(#{e}, #{d})"),
                 {^ok, g} <- echo("g(#{e})"),
                 {:ok, h} <- echo("h(#{f})"),
                 i = "i",
                 {^ok, j} <- echo("j(#{h}, #{i})") do
        Enum.join([a, b, c, d, e, f, g, h, i, j], " ")
      end

    assert result == "a b c(a) d e(a) f(e(a), d) g(e(a)) h(f(e(a), d)) i j(h(f(e(a), d)), i)"
  end

  test "works with clauses with ignored and unbound variables" do
    result =
      async with _..42 <- 1..42,
                {_ok, a} <- echo("a"),
                {_, _} = b <- echo("b(#{a})"),
                {_, _} <- {"c", "c"} do
        {:ok, b} = b
        Enum.join([a, b], " ")
      end

    assert result == "a b(a)"
  end

  test "works with clauses with variable rebinding" do
    a = "a"
    b = "b"

    result =
      async with {:ok, c} <- echo("c(#{a})"),
                 {:ok, d} <- echo("d"),
                 {:ok, _} = a <- echo("A"),
                 {:ok, a} <- a,
                 {:ok, e} <- echo("e(#{a})"),
                 {:ok, f} <- echo("f(#{e}, #{d})"),
                 {:ok, g} <- echo("g(#{e})"),
                 {:ok, _} = a <- echo("ä"),
                 {:ok, a} <- a,
                 e = "E",
                 {:ok, h} <- echo("h(#{f}, #{e})"),
                 {:ok, i} <- echo("i"),
                 {:ok, j} <- echo("j(#{h}, #{i})") do
        Enum.join([a, b, c, d, e, f, g, h, i, j], " ")
      end

    assert result == "ä b c(a) d E f(e(A), d) g(e(A)) h(f(e(A), d), E) i j(h(f(e(A), d), E), i)"
  end

  test "works with clauses with guards" do
    ok = :ok
    e = "e(a)"

    result =
      async with {:ok, a} <- echo("a"),
                 b = "b",
                 {:ok, c} <- echo("c(#{a})"),
                 {^ok, d} <- echo("d"),
                 {:ok, ^e} <- echo("e(#{a})"),
                 {:ok, f} when is_binary(f) <- echo("f(#{e}, #{d})"),
                 {ok, g} when ok == :ok <- echo("g(#{e})"),
                 {:ok, h} when is_binary(h) <- echo("h(#{f})"),
                 i = "i",
                 {^ok, j} <- echo("j(#{h}, #{i})") do
        Enum.join([a, b, c, d, e, f, g, h, i, j], " ")
      end

    assert result == "a b c(a) d e(a) f(e(a), d) g(e(a)) h(f(e(a), d)) i j(h(f(e(a), d)), i)"
  end

  test "works with clauses with complex pattern matching" do
    ok = :ok

    result =
      async with true <- get_true(),
                 {{:ok, a}, {:ok, a}} <- {echo("a"), echo("a")},
                 {^ok, {^ok, b}, {:ok, b}} <- {:ok, echo("b(#{a})"), {:ok, "b(a)"}} do
        Enum.join([a, b], " ")
      end

    assert result == "a b(a)"
  end

  test "works with bare expressions" do
    {:ok, agent} = Agent.start_link(fn -> 0 end)

    result =
      async with {:ok, a} <- echo(1),
                 Agent.update(agent, fn count -> count + a end),
                 {:ok, b} <- echo(2),
                 Agent.update(agent, fn count -> count + b end) do
        Enum.join([a, b], " ")
      end

    assert result == "1 2"
    assert Agent.get(agent, &(&1)) == 3

    :ok = Agent.stop(agent)
  end

  test "raises MatchError when the sides of a clause does not match" do
    assert_raise(MatchError, "no match of right hand side value: :error", fn ->
      async with {:ok, a} <- echo("a"),
                 {:ok, b} = error(a) do
        Enum.join([a, b], " ")
      end
    end)
  end

  test "returns the error if no else conditions are present" do
    result =
      async with {:ok, a} <- echo("a"),
                 {:ok, b} <- echo("b"),
                 {:ok, c} <- echo("c"),
                 {:ok, d} <- echo("d(#{a})"),
                 {:ok, e} <- error("e(#{b})"),
                 {:ok, f} <- echo("f(#{b})"),
                 {:ok, g} <- echo("g(#{e})") do
        Enum.join([a, b, c, d, e, f, g], " ")
      end

    assert result == :error
  end

  test "executes else conditions when present" do
    result =
      async with {:ok, a} <- echo("a"),
                 {:ok, b} <- echo("b"),
                 {:ok, c} <- echo("c"),
                 {:ok, d} <- echo("d(#{a})"),
                 {:ok, e} <- error("e(#{b})"),
                 {:ok, f} <- echo("f(#{b})"),
                 {:ok, g} <- echo("g(#{e})") do
        Enum.join([a, b, c, d, e, f, g], " ")
      else
        {:error, error} -> error
        :error -> :test
      end

    assert result == :test
  end

  test "allows guards on else conditions" do
    result =
      async with {:ok, a} <- echo("a"),
                 {:ok, b} <- echo("b"),
                 {:ok, c} <- echo("c"),
                 {:ok, d} <- echo("d(#{a})"),
                 {:ok, e} <- error("e(#{b})"),
                 {:ok, f} <- echo("f(#{b})"),
                 {:ok, g} <- echo("g(#{e})") do
        Enum.join([a, b, c, d, e, f, g], " ")
      else
        error when is_atom(error) -> error
      end

    assert result == :error
  end

  test "does not leak variables to else conditions" do
   value = 1

   result =
     async with 1 <- value,
                value = 2,
                :ok <- error() do
      value
    else
      _ -> value
    end

   assert result == 1
   assert value == 1
 end

  test "raises AsyncWith.ClauseError when there are not else condition that match the error" do
    assert_raise(AsyncWith.ClauseError, "no async with clause matching: :error", fn ->
      async with {:ok, value} <- error() do
        value
      else
        {:error, error} -> error
      end
    end)
  end

  test "does not override CaseClauseError produced inside of else conditions" do
    assert_raise(CaseClauseError, "no case clause matching: :error", fn ->
      async with {:ok, value} <- error() do
        value
      else
        :error = error ->
          case error do
            {:error, error} -> error
          end
      end
    end)
  end

  test "does not override WithClauseError produced inside of else conditions" do
    assert_raise(WithClauseError, "no with clause matching: :error", fn ->
      async with {:ok, value} <- error() do
        value
      else
        :error = error ->
          with {:ok, value} <- error do
            value
          else
            {:error, error} -> error
          end
      end
    end)
  end

  @tag :capture_log
  test "returns `{:exit, reason}` when an exception is raised" do
    result =
      async with {:ok, a} <- echo("a"),
                 {:ok, b} <- echo("b"),
                 {:ok, c} <- echo("c"),
                 {:ok, d} <- echo("d(#{a})"),
                 {:ok, e} <- raise_oops("e(#{b})"),
                 {:ok, f} <- echo("f(#{b})"),
                 {:ok, g} <- echo("g(#{e})") do
        Enum.join([a, b, c, d, e, f, g], " ")
      end

    assert {:exit, {%RuntimeError{message: "oops"}, _}} = result
  end

  @tag :capture_log
  test "executes else conditions when an exception is raised" do
    result =
      async with {:ok, a} <- echo("a"),
                 {:ok, b} <- echo("b"),
                 {:ok, c} <- echo("c"),
                 {:ok, d} <- echo("d(#{a})"),
                 {:ok, e} <- raise_oops("e(#{b})"),
                 {:ok, f} <- echo("f(#{b})"),
                 {:ok, g} <- echo("g(#{e})") do
        Enum.join([a, b, c, d, e, f, g], " ")
      else
        {:exit, {exception, _}} -> exception
      end

    assert result == %RuntimeError{message: "oops"}
  end

  test "accumulates timeouts to avoid undesired timeout errors with large graphs" do
    result =
      async with {:ok, a} <- delay(@async_with_timeout - 10, echo("a")),
                 {:ok, b} <- delay(@async_with_timeout - 10, echo("b")),
                 {:ok, c} <- delay(@async_with_timeout - 10, echo("c")),
                 {:ok, d} <- delay(@async_with_timeout - 10, echo("d(#{a})")),
                 {:ok, e} <- delay(@async_with_timeout - 10, echo("e(#{b})")),
                 {:ok, f} <- delay(@async_with_timeout - 10, echo("f(#{b})")),
                 {:ok, g} <- delay(@async_with_timeout - 10, echo("g(#{e})")) do
        Enum.join([a, b, c, d, e, f, g], " ")
      end

    assert result == "a b c d(a) e(b) f(b) g(e(b))"
  end

  test "returns `{:exit, :timeout}` when one of the tasks times out" do
    result =
      async with {:ok, a} <- delay(@async_with_timeout - 40, echo("a")),
                 {:ok, b} <- delay(@async_with_timeout - 40, echo("b")),
                 {:ok, c} <- delay(@async_with_timeout - 10, echo("c")),
                 {:ok, d} <- delay(@async_with_timeout - 40, echo("d(#{a})")),
                 {:ok, e} <- delay(@async_with_timeout + 10, echo("e(#{b})")),
                 {:ok, f} <- delay(@async_with_timeout - 40, echo("f(#{b})")),
                 {:ok, g} <- delay(@async_with_timeout - 40, echo("g(#{e})")) do
        Enum.join([a, b, c, d, e, f, g], " ")
      end

    assert result == {:exit, :timeout}
  end

  test "executes else conditions when one of the tasks times out" do
    result =
      async with {:ok, a} <- delay(@async_with_timeout - 40, echo("a")),
                 {:ok, b} <- delay(@async_with_timeout - 40, echo("b")),
                 {:ok, c} <- delay(@async_with_timeout - 10, echo("c")),
                 {:ok, d} <- delay(@async_with_timeout - 40, echo("d(#{a})")),
                 {:ok, e} <- delay(@async_with_timeout + 10, echo("e(#{b})")),
                 {:ok, f} <- delay(@async_with_timeout - 40, echo("f(#{b})")),
                 {:ok, g} <- delay(@async_with_timeout - 40, echo("g(#{e})")) do
        Enum.join([a, b, c, d, e, f, g], " ")
      else
        {:exit, :timeout} -> :timeout
      end

    assert result == :timeout
  end

  test "executes each clause in a different process" do
    result =
      async with {:ok, pid_a} <- pid(),
                 {:ok, pid_b} <- pid(),
                 {:ok, pid_c} <- pid(pid_a),
                 {:ok, pid_d} <- pid(),
                 {:ok, pid_e} <- pid(pid_a),
                 {:ok, pid_f} <- pid([pid_e, pid_d]),
                 {:ok, pid_g} <- pid(pid_e),
                 {:ok, pid_h} <- pid(pid_f),
                 {:ok, pid_i} <- pid(),
                 {:ok, pid_j} <- pid([pid_h, pid_i]) do
        Enum.uniq([pid_a, pid_b, pid_c, pid_d, pid_e, pid_f, pid_g, pid_h, pid_i, pid_j])
      else
        _ -> []
      end

    assert length(result) == 10
  end

  test "kills all the spawned processes on error" do
    {:ok, agent} = Agent.start_link(fn -> %{} end)

    result =
      async with {:ok, a} <- echo("a"),
                 {:ok, b} <- echo("b(#{a})"),
                 {:ok, c} <- echo("c(#{a})"),
                 # Delay execution so the processes e and f are spawned
                 {:ok, d} <- delay(@async_with_timeout - 30, error("d(#{b})")),
                 {:ok, e} <- delay(1_000, {pid_registry(agent, :e), "e(#{c})"}),
                 {:ok, f} <- delay(1_000, {pid_registry(agent, :f), "f(#{c})"}),
                 {:ok, g} <- delay(1_000, {pid_registry(agent, :g), "g(#{e})"}) do
        Enum.join([a, b, c, d, e, f, g], " ")
      end

    pids = Agent.get(agent, &(&1))
    :timer.sleep(10) # Let the tasks shutdown, but not time out

    assert result == :error
    refute Process.alive?(pids.e)
    refute Process.alive?(pids.f)
    refute Map.has_key?(pids, :g)

    :ok = Agent.stop(agent)
  end

  @tag :capture_log
  test "kills all the spawned processes when an exception is raised" do
    {:ok, agent} = Agent.start_link(fn -> %{} end)

    result =
      async with {:ok, a} <- echo("a"),
                 {:ok, b} <- echo("b(#{a})"),
                 {:ok, c} <- echo("c(#{a})"),
                 {:ok, d} <- delay(1_000, {pid_registry(agent, :d), "d(#{b})"}),
                 {:ok, e} <- delay(1_000, {pid_registry(agent, :e), "e(#{c})"}),
                 # Delay execution so the processes d and e are spawned
                 {:ok, f} <- delayed_raise_oops(@async_with_timeout - 30, "f(#{c})"),
                 {:ok, g} <- delay(1_000, {pid_registry(agent, :g), "g(#{e})"}) do
        Enum.join([a, b, c, d, e, f, g], " ")
      end

    pids = Agent.get(agent, &(&1))
    :timer.sleep(10) # Let the tasks shutdown, but not time out

    assert {:exit, {%RuntimeError{message: "oops"}, _}} = result
    refute Process.alive?(pids.d)
    refute Process.alive?(pids.e)
    refute Map.has_key?(pids, :g)

    :ok = Agent.stop(agent)
  end

  test "kills all the spawned processes when one of the tasks times out" do
    {:ok, agent} = Agent.start_link(fn -> %{} end)

    result =
      async with {:ok, a} <- echo("a"),
                 {:ok, b} <- echo("b(#{a})"),
                 {:ok, c} <- echo("c(#{a})"),
                 {:ok, d} <- delay(1_000, {pid_registry(agent, :d), "d(#{b})"}),
                 {:ok, e} <- delay(1_000, {pid_registry(agent, :e), "e(#{c})"}),
                 # Delay execution so the processes e and f are spawned
                 {:ok, f} <- delay(@async_with_timeout + 10, echo("f(#{c})")),
                 {:ok, g} <- delay(1_000, {pid_registry(agent, :g), "g(#{e})"}) do
        Enum.join([a, b, c, d, e, f, g], " ")
      end

    pids = Agent.get(agent, &(&1))
    :timer.sleep(10) # Let the tasks shutdown, but not time out

    assert result == {:exit, :timeout}
    refute Process.alive?(pids.d)
    refute Process.alive?(pids.e)
    refute Map.has_key?(pids, :g)

    :ok = Agent.stop(agent)
  end

  test "optimizes the execution" do
    started_at = DateTime.to_unix(DateTime.utc_now, :milliseconds)

    result =
      async with {:ok, a} <- delay(20, echo("a")),
                 {:ok, b} <- delay(20, echo("b")),
                 {:ok, c} <- delay(40, echo("c")),
                 {:ok, d} <- delay(20, echo("d(#{a})")),
                 {:ok, e} <- delay(40, echo("e(#{b})")),
                 {:ok, f} <- delay(20, echo("f(#{b})")),
                 {:ok, g} <- delay(20, echo("g(#{e})")) do
        Enum.join([a, b, c, d, e, f, g], " ")
      end

    # The dependency graph is:
    #
    #           A(20)        B(20)       C(40)
    #             ↓          ↙  ↘
    #           C(20)   E(40)    F(20)
    #                     ↓
    #                   G(20)
    #
    # The most time consuming path should be B -> E -> G ~ 400 milliseconds

    finished_at = DateTime.to_unix(DateTime.utc_now, :milliseconds)

    assert result == "a b c d(a) e(b) f(b) g(e(b))"
    assert finished_at - started_at < 95
  end

  test "errors with the same internal representation are not misinterpreted" do
    result =
      async with {:ok, a} <- echo("a"),
                 {:ok, {b}} <- {:ok, [1]} do
        Enum.join([a, b], " ")
      end

    assert result == {:ok, [1]}
  end
end