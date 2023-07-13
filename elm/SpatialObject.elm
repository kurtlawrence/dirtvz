port module SpatialObject exposing (..)

import Json.Decode as D exposing (Value)
import Json.Decode.Pipeline as P
import List.Extra as Listx
import Progress exposing (Progress)


type alias SpatialObject =
    { key : String
    , status : String
    , prg : Maybe Progress
    }


preprocessing : String
preprocessing =
    "preprocessing"


deleting : String
deleting =
    "deleting"


decode : D.Decoder SpatialObject
decode =
    D.succeed SpatialObject
        |> P.required "key" D.string
        |> P.optional "status" D.string "needs-reload"
        |> P.hardcoded Nothing


port object_list : (Value -> msg) -> Sub msg


objectList : (List SpatialObject -> msg) -> Sub msg
objectList toMsg =
    object_list
        (D.decodeValue (D.list decode)
            >> Result.withDefault []
            >> toMsg
        )


setProgress : Progress -> String -> List SpatialObject -> List SpatialObject
setProgress p key =
    Listx.updateIf
        (.key >> (==) key)
        (\x -> { x | prg = Just p })
