import gleam/erlang/process.{type Subject}
import gleam/list

pub type Message(input_type) {
  Input(input: input_type)
  Shutdown
}

type State(input_type, ok_type, error_type) {
  State(
    reply_subject: Subject(ok_type),
    main_subject: Subject(Message(input_type)),
    map_func: fn(input_type) -> ok_type,
  )
}

pub fn new(
  reply_subject: Subject(ok_type),
  map_func: fn(input_type) -> ok_type,
) -> #(process.Pid, Subject(Message(input_type))) {
  let response = process.new_subject()
  let pid =
    process.start(
      running: fn() {
        let main_subject = process.new_subject()
        process.send(response, main_subject)
        loop(State(reply_subject:, main_subject:, map_func:))
      },
      linked: True,
    )
  #(pid, process.receive_forever(response))
}

fn loop(state: State(input_type, ok_type, error_type)) {
  case process.receive_forever(state.main_subject) {
    Input(input:) -> {
      process.send(state.reply_subject, state.map_func(input))
      loop(state)
    }
    Shutdown -> Nil
  }
}

pub fn kill_workers_now(workers: List(process.Pid)) {
  list.each(workers, fn(x) {
    process.unlink(x)
    process.kill(x)
  })
}
