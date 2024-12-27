import gleam/erlang/atom
import gleam/erlang/process
import gleam/list
import gleam/result
import gleam/yielder.{type Yielder}
import parallel_map/internal/task_repeater

/// This type is used to specify the number of workers to spawn
pub type WorkerAmount {
  /// will spawn that number of workers
  WorkerAmount(value: Int)
  /// will spawn workers to match the amount of
  /// schedulers currently online
  MatchSchedulersOnline
}

fn worker_amount_to_int(worker_amount: WorkerAmount) -> Int {
  case worker_amount {
    WorkerAmount(amount) -> amount
    MatchSchedulersOnline ->
      do_erlang_system_info(atom.create_from_string("schedulers_online"))
  }
}

@external(erlang, "erlang", "system_info")
fn do_erlang_system_info(item: atom.Atom) -> Int

/// This function behaves similarly to gleam/yielder's yielder.map
///
/// Creates an yielder from an existing yielder and a transformation function
///
/// Each element in the new yielder will be the result of calling the given
/// function on the elements in the given yielder, with the resulting value
/// wrapped in a Result
///
/// If the timeout specified is exceeded while attempting
/// to collect the result of the computation, the element will instead be Error(Nil)
///
/// This function also differs from yielder.map in that it will spawn the workers
/// and perform the computation right when it is called,
/// but it does not attempt to collect the result until the yielder is later run
pub fn yielder_pmap(
  input: Yielder(a),
  mapping_func: fn(a) -> b,
  num_workers: WorkerAmount,
  timeout_milliseconds: Int,
) -> Yielder(Result(b, Nil)) {
  let worker_amount = case worker_amount_to_int(num_workers) {
    x if x > 0 -> x
    _ -> panic as "number of workers must be greater than 0"
  }

  let #(worker_list, subject_list) =
    yielder.repeatedly(fn() {
      let new_subject = process.new_subject()
      let assert Ok(worker_subject) =
        task_repeater.new(new_subject, fn(x) { mapping_func(x) |> Ok })

      #(worker_subject, new_subject)
    })
    |> yielder.take(worker_amount)
    |> yielder.to_list()
    |> list.unzip

  let worker_yielder =
    worker_list
    |> yielder.from_list
    |> yielder.cycle
  let subject_yielder =
    subject_list
    |> yielder.from_list
    |> yielder.cycle

  let output_length =
    yielder.zip(input, worker_yielder)
    |> yielder.map(fn(x) {
      let #(input_value, worker) = x
      task_repeater.call(worker, input_value)
    })
    |> yielder.length()

  subject_yielder
  |> yielder.take(output_length)
  |> yielder.map(fn(subject) {
    process.receive(subject, timeout_milliseconds)
    |> result.map_error(fn(_) { Nil })
    |> result.flatten()
  })
}

/// This function behaves similarly to gleam_stdlib's yielder.map
///
/// Returns a new list containing only the elements of the first list
/// after the function has been applied to each one, with the resulting value
/// wrapped in a Result
///
/// If the timeout specified is exceeded while attempting
/// to collect the result of the computation, the value will instead be Error(Nil)
pub fn list_pmap(
  input: List(a),
  mapping_func: fn(a) -> b,
  num_workers: WorkerAmount,
  timeout_milliseconds: Int,
) -> List(Result(b, Nil)) {
  input
  |> yielder.from_list
  |> yielder_pmap(mapping_func, num_workers, timeout_milliseconds)
  |> yielder.to_list
}

/// This function behaves similarly to gleam_stdlib's yielder.find_map
pub fn yielder_find_pmap(
  input: Yielder(a),
  mapping_func: fn(a) -> Result(b, c),
  num_workers: WorkerAmount,
  timeout_milliseconds: Int,
) -> Result(b, Nil) {
  let worker_amount = case worker_amount_to_int(num_workers) {
    x if x > 0 -> x
    _ -> panic as "number of workers must be greater than 0"
  }

  let #(worker_list, subject_list) =
    yielder.repeatedly(fn() {
      let new_subject = process.new_subject()
      let assert Ok(worker) = task_repeater.new(new_subject, mapping_func)
      #(worker, new_subject)
    })
    |> yielder.take(worker_amount)
    |> yielder.to_list()
    |> list.unzip

  let worker_yielder =
    worker_list
    |> yielder.from_list
    |> yielder.cycle
  let subject_yielder =
    subject_list
    |> yielder.from_list
    |> yielder.cycle

  let output_length =
    yielder.zip(input, worker_yielder)
    |> yielder.map(fn(x) {
      let #(input_value, worker) = x
      task_repeater.find_call(worker, input_value)
    })
    |> yielder.length()

  let close_workers = fn() {
    worker_list
    |> list.each(fn(worker) { process.send(worker, task_repeater.SetTerminate) })
  }

  subject_yielder
  |> yielder.take(output_length)
  |> yielder.try_fold(Error(Nil), fn(_, subject) {
    case process.receive(subject, timeout_milliseconds) {
      Ok(Ok(value)) -> {
        close_workers()
        Error(Ok(value))
      }
      Ok(Error(_)) -> Ok(Error(Nil))
      Error(_) -> Ok(Error(Nil))
    }
  })
  |> result.unwrap_both
}

/// This function behaves similarly to gleam_stdlib's list.find_map
pub fn list_find_pmap(
  input: List(a),
  mapping_func: fn(a) -> Result(b, c),
  num_workers: WorkerAmount,
  timeout_milliseconds: Int,
) -> Result(b, Nil) {
  input
  |> yielder.from_list
  |> yielder_find_pmap(mapping_func, num_workers, timeout_milliseconds)
}
