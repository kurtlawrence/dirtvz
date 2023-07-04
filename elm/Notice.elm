port module Notice exposing (..)

import Task


type Notice
    = None
    | Waiting String
    | Ok String
    | Err String


toCmd : (String -> Notice) -> (Notice -> a) -> String -> Cmd a
toCmd n toMsg s =
    Task.perform (n >> toMsg) (Task.succeed s)


ok =
    toCmd Ok


err =
    toCmd Err


waiting =
    toCmd Waiting


sendOk : String -> Cmd a
sendOk =
    Ok >> send


sendWaiting : String -> Cmd a
sendWaiting =
    Waiting >> send


sendErr : String -> Cmd a
sendErr =
    Err >> send


send : Notice -> Cmd a
send n =
    let
        ( lvl, msg ) =
            case n of
                None ->
                    ( "None", "" )

                Waiting x ->
                    ( "Waiting", x )

                Ok x ->
                    ( "Ok", x )

                Err x ->
                    ( "Err", x )
    in
    set_notice { lvl = lvl, msg = msg }


recv : (Notice -> a) -> Notice_ -> a
recv toMsg { lvl, msg } =
    toMsg <|
        case lvl of
            "Waiting" ->
                Waiting msg

            "Ok" ->
                Ok msg

            "Err" ->
                Err msg

            _ ->
                None


type alias Notice_ =
    { lvl : String
    , msg : String
    }


port set_notice : Notice_ -> Cmd a


port get_notice : (Notice_ -> a) -> Sub a
