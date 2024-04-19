# parallel_map

[![Package Version](https://img.shields.io/hexpm/v/parallel_map)](https://hex.pm/packages/parallel_map)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/parallel_map/)

This is a simple package that adds a `iterator_pmap` and `list_pmap`,
which has a similar behaviour and interface as `iterator.map` and `list.map`,
except it runs in parallel by spawning extra processes to do the work.

```sh
gleam add parallel_map
```
```gleam
import gleam/list
import gleam/iterator
import gleam/result
import parallel_map

pub fn main() {
  let map_func = fn(a: Int) -> Int {a * a}

  let iterator_input = iterator.range(0, 1000)

  iterator_input
  |> iterator.map(map_func)

  // can be rewritten as
  iterator_input
  |> parallel_map.iterator_pmap(map_func, 16, 100)
  |> iterator.map(result.unwrap(_, -1))

  let list_input = list.range(0, 1000)

  list_input
  |> list.map(map_func)

  // can be rewritten as
  list_input
  |> parallel_map.list_pmap(map_func, 16, 100)
  |> list.map(result.unwrap(_, -1))
}
```

Further documentation can be found at <https://hexdocs.pm/parallel_map>.

## Development

```sh
gleam run   # Run the project
gleam test  # Run the tests
gleam shell # Run an Erlang shell
```
