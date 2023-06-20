port module Ports exposing (..)

import Json.Decode as D exposing (Value)
import Json.Decode.Pipeline as P
import SpatialObject


type alias HoverInfo =
    { pointerx : Int
    , pointery : Int
    , renderPt : Maybe Point3
    , worldPt : Maybe Point3
    , meshName : Maybe String
    }


type alias Point3 =
    { x : Float, y : Float, z : Float }


decodePoint3 : D.Decoder Point3
decodePoint3 =
    D.succeed Point3
        |> P.required "x" D.float
        |> P.required "y" D.float
        |> P.required "z" D.float


port pickSpatialFile : () -> Cmd a


port objectList : (List SpatialObject.SpatialObject -> msg) -> Sub msg


port deleteSpatialObject : String -> Cmd a


port toggleLoaded : String -> Cmd a


hoverinfo : (Maybe HoverInfo -> msg) -> Sub msg
hoverinfo toMsg =
    hoverInfo
        (D.decodeString
            (D.succeed HoverInfo
                |> P.required "pointerx" D.int
                |> P.required "pointery" D.int
                |> null "render_pt" decodePoint3
                |> null "world_pt" decodePoint3
                |> null "mesh_name" D.string
            )
            >> Result.mapError (Debug.log "Decode error")
            >> Result.toMaybe
            >> toMsg
        )


port hoverInfo : (String -> msg) -> Sub msg


null : String -> (D.Decoder a) -> D.Decoder (Maybe a -> b) -> D.Decoder b
null field dec =
    P.optional field (D.map Just dec) Nothing
