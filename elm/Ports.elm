port module Ports exposing (..)

import SpatialObject


port pickSpatialFile : () -> Cmd a


port objectList : (List SpatialObject.SpatialObject -> msg) -> Sub msg

port deleteSpatialObject : String -> Cmd a