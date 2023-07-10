module Cmn exposing (..)

import Html.Styled as Html
import Html.Styled.Events exposing (on)
import Json.Decode
import Task


cmd : a -> Cmd a
cmd x =
    Task.succeed x |> Task.perform identity


maybeFilter : (a -> Bool) -> Maybe a -> Maybe a
maybeFilter pred =
    Maybe.andThen
        (\x ->
            if pred x then
                Just x

            else
                Nothing
        )


onEnter : msg -> Html.Attribute msg
onEnter m =
    on "keydown"
        (Json.Decode.field "key" Json.Decode.string
            |> Json.Decode.andThen
                (\x ->
                    if x == "Enter" then
                        Json.Decode.succeed m

                    else
                        Json.Decode.fail ""
                )
        )
