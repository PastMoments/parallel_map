# parallel_map

[![Package Version](https://img.shields.io/hexpm/v/parallel_map)](https://hex.pm/packages/parallel_map)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/parallel_map/)

Note: This package only works for the erlang target.

This is a simple gleam library that adds a `yielder_pmap` and `list_pmap`,
which has a similar behaviour and interface as `yielder.map` (from `gleam/yielder`) and `list.map` (from the standard library),
except it runs in parallel by spawning extra processes to do the work.

There is also `yielder_find_pmap` and `list_find_pmap` which stop the whole
parallel execution after finding the first **Ok** value.

```sh
gleam add parallel_map
```
```gleam
import gleam/list
import gleam/yielder
import gleam/result
import parallel_map.{MatchSchedulers, WorkerAmount}

pub fn main() {
  let map_func = fn(a: Int) -> Int {a * a}

  let yielder_input = yielder.range(0, 1000)

  yielder_input
  |> yielder.map(map_func)

  // can be rewritten as
  yielder_input
  |> parallel_map.yielder_pmap(map_func, WorkerAmount(16), 100)
  |> yielder.map(result.unwrap(_, -1))

  let list_input = list.range(0, 1000)

  list_input
  |> list.map(map_func)

  // can be rewritten as
  list_input
  |> parallel_map.list_pmap(map_func, MatchSchedulersOnline, 100)
  |> list.map(result.unwrap(_, -1))


  // there is also
  //   parallel_map.yielder_find_pmap similar to yielder.find_map
  //   parallel_map.list_find_pmap similar to list.find_map,
  // which stop the works after finding the first Ok value.

  let find_map_func = fn(a: Int) -> Result(Int, Int) {
    case a {
      x if x > 500 -> Ok(x * 2)
      _ -> Error(a)
    }
  }

  yielder_input
  |> yielder.find_map(find_map_func)

  // can be rewritten as
  yielder_input
  |> parallel_map.yielder_find_pmap(find_map_func, WorkerAmount(16), 100)


  list_input
  |> list.find_map(find_map_func)

  // can be rewritten as
  list_input
  |> parallel_map.list_find_pmap(find_map_func, MatchSchedulersOnline, 100)
}
```

Further documentation can be found at <https://hexdocs.pm/parallel_map>.

## Development

```sh
gleam run   # Run the project
gleam test  # Run the tests
gleam shell # Run an Erlang shell
```
