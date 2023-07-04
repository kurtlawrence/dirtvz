module Cmn exposing (..)

import Css
import Task


cmd : a -> Cmd a
cmd x =
    Task.succeed x |> Task.perform identity


theme =
    { primary1 = Css.rgb 127 127 127
    }
