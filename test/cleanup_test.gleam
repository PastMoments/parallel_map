import gleam/erlang/process
import gleam/list
import gleam/yielder
import gleeunit/should
import parallel_map

const worker_count = 30

type SystemInfo {
  ProcessCount
}

@external(erlang, "erlang", "system_info")
fn do_erlang_system_info(item: SystemInfo) -> Int

pub fn process_count_test() {
  let initial_process_count = do_erlang_system_info(ProcessCount)
  let _ =
    list.repeat(Nil, worker_count)
    |> parallel_map.list_find_pmap(
      fn(_) { Ok(Nil) },
      parallel_map.WorkerAmount(worker_count),
      1000,
    )
  do_erlang_system_info(ProcessCount) |> should.equal(initial_process_count)

  let _ =
    list.repeat(Nil, worker_count)
    |> parallel_map.list_find_pmap(
      fn(_) { Error(Nil) },
      parallel_map.WorkerAmount(worker_count),
      1000,
    )
  do_erlang_system_info(ProcessCount) |> should.equal(initial_process_count)
  let _ =
    list.repeat(Nil, worker_count)
    |> parallel_map.list_pmap(
      fn(_) { Ok(Nil) },
      parallel_map.WorkerAmount(worker_count),
      1000,
    )

  do_erlang_system_info(ProcessCount) |> should.equal(initial_process_count)
}

pub fn find_map_early_cleanup_test() {
  let initial_process_count = do_erlang_system_info(ProcessCount)
  let counter = process.new_subject()
  let _ =
    list.range(1, 50)
    |> parallel_map.list_find_pmap(
      fn(x) {
        let result = case x {
          36 -> Ok(1)
          _ -> Error(Nil)
        }
        process.send(counter, result)
        result
      },
      parallel_map.WorkerAmount(30),
      1000,
    )
  process.sleep(100)
  do_erlang_system_info(ProcessCount) |> should.equal(initial_process_count)

  should.be_true(
    yielder.repeat(counter)
    |> yielder.fold_until(0, fn(acc, counter) {
      case process.receive_forever(counter) {
        Ok(1) -> list.Stop(acc + 1)
        Error(Nil) -> list.Continue(acc + 1)
        _ -> panic
      }
    })
    < 37,
  )
}
