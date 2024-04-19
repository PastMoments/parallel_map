import gleam/iterator
import gleam/list
import gleam/result
import gleeunit
import gleeunit/should
import parallel_map

pub fn main() {
  gleeunit.main()
}

pub fn readme_list_test() {
  let map_func = fn(a: Int) -> Int { a * a }
  let list_input = list.range(0, 1000)
  should.equal(
    list_input
      |> parallel_map.list_pmap(map_func, 16, 100)
      |> list.map(result.unwrap(_, -1)),
    list_input
      |> list.map(map_func),
  )
}

pub fn readme_iterator_test() {
  let map_func = fn(a: Int) -> Int { a * a }
  let iterator_input = iterator.range(0, 1000)
  should.equal(
    iterator_input
      |> parallel_map.iterator_pmap(map_func, 16, 100)
      |> iterator.map(result.unwrap(_, -1))
      |> iterator.to_list,
    iterator_input
      |> iterator.map(map_func)
      |> iterator.to_list,
  )
}
