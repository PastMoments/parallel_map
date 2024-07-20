import gleam/erlang/process.{type Subject}
import gleam/otp/actor

pub type ActorState(input_type, ok_type, error_type) {
  ActorState(
    reply_subject: Subject(Result(ok_type, error_type)),
    map_func: fn(input_type) -> Result(ok_type, error_type),
    should_terminate: Bool,
  )
}

pub fn new(
  reply_subject: Subject(Result(ok_type, error_type)),
  map_func: fn(input_type) -> Result(ok_type, error_type),
) -> Result(Subject(Message(input_type, ok_type, error_type)), actor.StartError) {
  actor.start(ActorState(reply_subject, map_func, False), handle_message)
}

pub fn call(
  task_repeater: Subject(Message(input_type, ok_type, error_type)),
  input: input_type,
) -> Nil {
  actor.send(task_repeater, Call(input))
}

pub fn find_call(
  task_repeater: Subject(Message(input_type, ok_type, error_type)),
  input: input_type,
) -> Nil {
  actor.send(task_repeater, FindCall(input))
}

pub fn close(
  task_repeater: Subject(Message(input_type, ok_type, error_type)),
) -> Nil {
  actor.send(task_repeater, Shutdown)
}

pub type Message(input_type, ok_type, error_type) {
  Call(input: input_type)
  FindCall(input: input_type)
  Shutdown
  SetTerminate
}

fn handle_message(
  message: Message(input_type, ok_type, error_type),
  actor_state: ActorState(input_type, ok_type, error_type),
) -> actor.Next(
  Message(input_type, ok_type, error_type),
  ActorState(input_type, ok_type, error_type),
) {
  case actor_state.should_terminate {
    True -> actor.Stop(process.Normal)
    False -> {
      case message {
        Shutdown -> actor.Stop(process.Normal)
        Call(input) -> {
          actor.send(actor_state.reply_subject, actor_state.map_func(input))
          actor.continue(actor_state)
        }
        FindCall(input) -> {
          let result = actor_state.map_func(input)
          actor.send(actor_state.reply_subject, result)
          case result {
            Ok(_) -> actor.Stop(process.Normal)
            Error(_) -> actor.continue(actor_state)
          }
        }
        SetTerminate ->
          actor.continue(ActorState(..actor_state, should_terminate: True))
      }
    }
  }
}
