defmodule Dataloader.LimitQueryTest do
  use ExUnit.Case, async: true

  alias Dataloader.{User, Post}
  import Ecto.Query
  alias Dataloader.TestRepo, as: Repo

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)

    test_pid = self()

    source =
      Dataloader.Ecto.new(
        Repo,
        query: &query(&1, &2, test_pid)
      )

    loader =
      Dataloader.new()
      |> Dataloader.add_source(Test, source)

    {:ok, loader: loader}
  end

  defp query(Post, %{limit: limit}, test_pid) do
    send(test_pid, :querying)

    Post
    |> where([p], is_nil(p.deleted_at))
    |> order_by(asc: :id)
    |> limit(^limit)
  end

  defp query(queryable, _args, test_pid) do
    send(test_pid, :querying)
    queryable
  end

  test "Query limit does not apply globally", %{loader: loader} do
    user1 = %User{username: "Ben Wilson"} |> Repo.insert!()
    user2 = %User{username: "Bruce Williams"} |> Repo.insert!()

    [post1, _post2, post3, _post4] =
      [
        %Post{user_id: user1.id, title: "foo"},
        %Post{user_id: user1.id, title: "baz"},
        %Post{user_id: user2.id, title: "bar"},
        %Post{user_id: user2.id, title: "qux"}
      ]
      |> Enum.map(&Repo.insert!/1)

    args = {{:many, Post}, %{limit: 1}}

    loader =
      loader
      |> Dataloader.load(Test, args, user_id: user1.id)
      |> Dataloader.load(Test, args, user_id: user2.id)
      |> Dataloader.run()

    assert [post1] == Dataloader.get(loader, Test, args, user_id: user1.id)
    assert [post3] == Dataloader.get(loader, Test, args, user_id: user2.id)
  end
end