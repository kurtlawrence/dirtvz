module Cmn exposing (..)

import Task


cmd : a -> Cmd a
cmd x =
    Task.succeed x |> Task.perform identity
