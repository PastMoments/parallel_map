import gleam/erlang/process.{type Subject}
import gleam/otp/actor

pub type ActorState(input_type, return_type) {
  ActorState(
    reply_subject: Subject(return_type),
    map_func: fn(input_type) -> return_type,
  )
}

pub fn new(
  reply_subject: Subject(return_type),
  map_func: fn(input_type) -> return_type,
) -> Result(Subject(Message(input_type, return_type)), actor.StartError) {
  actor.start(ActorState(reply_subject, map_func), handle_message)
}

pub fn call(
  task_repeater: Subject(Message(input_type, return_type)),
  input: input_type,
) -> Nil {
  actor.send(task_repeater, Call(input))
}

pub fn close(task_repeater: Subject(Message(input_type, return_type))) -> Nil {
  actor.send(task_repeater, Shutdown)
}

pub type Message(input_type, return_type) {
  Call(input: input_type)
  Shutdown
}

fn handle_message(
  message: Message(input_type, return_type),
  actor_state: ActorState(input_type, return_type),
) -> actor.Next(
  Message(input_type, return_type),
  ActorState(input_type, return_type),
) {
  case message {
    Shutdown -> actor.Stop(process.Normal)
    Call(input) -> {
      actor.send(actor_state.reply_subject, actor_state.map_func(input))
      actor.continue(actor_state)
    }
  }
}
