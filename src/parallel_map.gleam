import gleam/erlang/atom
import gleam/erlang/process
import gleam/io
import gleam/iterator.{type Iterator}
import gleam/list
import gleam/result
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

/// This function behaves similarly to gleam_stdlib's iterator.map
///
/// Creates an iterator from an existing iterator and a transformation function
///
/// Each element in the new iterator will be the result of calling the given
/// function on the elements in the given iterator, with the resulting value
/// wrapped in a Result
///
/// If the timeout specified is exceeded while attempting
/// to collect the result of the computation, the element will instead be Error(Nil)
///
/// This function also differs from iterator.map in that it will spawn the workers
/// and perform the computation right when it is called,
/// but it does not attempt to collect the result until the iterator is later run
pub fn iterator_pmap(
  input: Iterator(a),
  mapping_func: fn(a) -> b,
  num_workers: WorkerAmount,
  timeout_milliseconds: Int,
) -> Iterator(Result(b, Nil)) {
  let worker_amount = case worker_amount_to_int(num_workers) {
    x if x > 0 -> x
    _ -> panic as "number of workers must be greater than 0"
  }

  let #(worker_list, subject_list) =
    iterator.repeatedly(fn() {
      let new_subject = process.new_subject()
      let assert Ok(worker_subject) =
        task_repeater.new(new_subject, fn(x) { mapping_func(x) |> Ok })

      #(worker_subject, new_subject)
    })
    |> iterator.take(worker_amount)
    |> iterator.to_list()
    |> list.unzip

  let worker_iterator =
    worker_list
    |> iterator.from_list
    |> iterator.cycle
  let subject_iterator =
    subject_list
    |> iterator.from_list
    |> iterator.cycle

  let output_length =
    iterator.zip(input, worker_iterator)
    |> iterator.map(fn(x) {
      let #(input_value, worker) = x
      task_repeater.call(worker, input_value)
    })
    |> iterator.length()

  subject_iterator
  |> iterator.take(output_length)
  |> iterator.map(fn(subject) {
    process.receive(subject, timeout_milliseconds)
    |> result.map_error(fn(_) { Nil })
    |> result.flatten()
  })
}

/// This function behaves similarly to gleam_stdlib's iterator.map
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
  |> iterator.from_list
  |> iterator_pmap(mapping_func, num_workers, timeout_milliseconds)
  |> iterator.to_list
}

/// This function behaves similarly to gleam_stdlib's iterator.find_map
pub fn iterator_find_pmap(
  input: Iterator(a),
  mapping_func: fn(a) -> Result(b, c),
  num_workers: WorkerAmount,
  timeout_milliseconds: Int,
) -> Result(b, Nil) {
  let worker_amount = case worker_amount_to_int(num_workers) {
    x if x > 0 -> x
    _ -> panic as "number of workers must be greater than 0"
  }

  let #(worker_list, subject_list) =
    iterator.repeatedly(fn() {
      let new_subject = process.new_subject()
      let assert Ok(worker) = task_repeater.new(new_subject, mapping_func)
      #(worker, new_subject)
    })
    |> iterator.take(worker_amount)
    |> iterator.to_list()
    |> list.unzip

  let worker_iterator =
    worker_list
    |> iterator.from_list
    |> iterator.cycle
  let subject_iterator =
    subject_list
    |> iterator.from_list
    |> iterator.cycle

  let output_length =
    iterator.zip(input, worker_iterator)
    |> iterator.map(fn(x) {
      let #(input_value, worker) = x
      task_repeater.find_call(worker, input_value)
    })
    |> iterator.length()

  let close_workers = fn() {
    worker_list
    |> list.each(fn(worker) { process.send(worker, task_repeater.SetTerminate) })
  }

  subject_iterator
  |> iterator.take(output_length)
  |> iterator.try_fold(Error(Nil), fn(_, subject) {
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
  |> iterator.from_list
  |> iterator_find_pmap(mapping_func, num_workers, timeout_milliseconds)
}
