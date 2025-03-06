import gleam/list
import gleam/result
import gleam/yielder
import gleeunit
import gleeunit/should
import parallel_map.{MatchSchedulersOnline, WorkerAmount}

pub fn main() {
  gleeunit.main()
}

pub fn readme_list_test() {
  let map_func = fn(a: Int) -> Int { a * a }
  let list_input = list.range(0, 1000)
  should.equal(
    list_input
      |> parallel_map.list_pmap(map_func, WorkerAmount(16), 100)
      |> list.map(result.unwrap(_, -1)),
    list_input
      |> list.map(map_func),
  )
}

pub fn readme_yielder_test() {
  let map_func = fn(a: Int) -> Int { a * a }
  let yielder_input = yielder.range(0, 1000)
  should.equal(
    yielder_input
      |> parallel_map.yielder_pmap(map_func, MatchSchedulersOnline, 100)
      |> yielder.map(result.unwrap(_, -1))
      |> yielder.to_list,
    yielder_input
      |> yielder.map(map_func)
      |> yielder.to_list,
  )
}

pub fn list_find_pmap_test() {
  let find_map_func = fn(a: Int) -> Result(Int, Int) {
    case a {
      x if x > 500 -> Ok(x * 2)
      _ -> Error(a)
    }
  }
  let list_input = list.range(0, 1000)

  let sequential_result = list_input |> list.find_map(find_map_func)

  let parallel_result =
    list_input
    |> parallel_map.list_find_pmap(find_map_func, WorkerAmount(16), 100)

  should.equal(parallel_result, sequential_result)
  should.equal(parallel_result, Ok(1002))
}

pub fn yielder_find_pmap_test() {
  let find_map_func = fn(a: Int) -> Result(Int, Int) {
    case a {
      x if x > 500 -> Ok(x * 2)
      _ -> Error(a)
    }
  }
  let yielder_input = yielder.range(0, 1000)

  let sequential_result = yielder_input |> yielder.find_map(find_map_func)

  let parallel_result =
    yielder_input
    |> parallel_map.yielder_find_pmap(find_map_func, MatchSchedulersOnline, 100)

  should.equal(parallel_result, sequential_result)
  should.equal(parallel_result, Ok(1002))
}
