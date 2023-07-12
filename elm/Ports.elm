port module Ports exposing (..)

import Json.Decode as D
import Json.Decode.Pipeline as P


type alias HoverInfo =
    { pointerx : Int
    , pointery : Int
    , renderPt : Maybe Point3
    , worldPt : Maybe Point3
    , meshName : Maybe String
    , tileId : Maybe Int
    , lodRes : Maybe Float
    }


type alias Point3 =
    { x : Float, y : Float, z : Float }


decodePoint3 : D.Decoder Point3
decodePoint3 =
    D.succeed Point3
        |> P.required "x" D.float
        |> P.required "y" D.float
        |> P.required "z" D.float


null : String -> D.Decoder a -> D.Decoder (Maybe a -> b) -> D.Decoder b
null field dec =
    P.optional field (D.map Just dec) Nothing


port pick_spatial_file : () -> Cmd a


port delete_spatial_object : String -> Cmd a


port object_load : String -> Cmd a


port object_unload : String -> Cmd a


hoverInfo : (Maybe HoverInfo -> msg) -> Sub msg
hoverInfo toMsg =
    hover_info
        (D.decodeString
            (D.succeed HoverInfo
                |> P.required "pointerx" (D.map round D.float)
                |> P.required "pointery" (D.map round D.float)
                |> null "render_pt" decodePoint3
                |> null "world_pt" decodePoint3
                |> null "mesh_name" D.string
                |> null "tile_id" D.int
                |> null "lod_res" D.float
            )
            -- >> Result.mapError (Debug.log "HoverInfo failed to deserialise")
            >> Result.toMaybe
            >> toMsg
        )


port hover_info : (String -> msg) -> Sub msg
