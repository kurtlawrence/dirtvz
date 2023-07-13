module Cmn exposing (..)

import Css exposing (..)
import Html.Styled as Html exposing (..)
import Html.Styled.Attributes as Attr exposing (css)
import Html.Styled.Events exposing (on, onClick, onInput, stopPropagationOn)
import Json.Decode
import Style
import Task


cmd : a -> Cmd a
cmd x =
    Task.succeed x |> Task.perform identity


swap : ( a, b ) -> ( b, a )
swap ( a, b ) =
    ( b, a )


maybeFilter : (a -> Bool) -> Maybe a -> Maybe a
maybeFilter pred =
    Maybe.andThen
        (\x ->
            if pred x then
                Just x

            else
                Nothing
        )


isJust : Maybe a -> Bool
isJust =
    Maybe.map (always True) >> Maybe.withDefault False



-- UI


textInput : String -> (String -> a) -> List (Attribute a) -> Html.Html a
textInput value msg attrs =
    Html.input
        ([ Attr.value value
         , onInput msg
         , Attr.type_ "text"
         ]
            ++ attrs
        )
        []


type alias Popup a =
    { header : String
    , body : Html.Html a
    , cancelMsg : String
    , onCancel : a
    , okMsg : String
    , onOk : a
    }


popup : Popup a -> Html.Html a
popup { header, body, cancelMsg, onCancel, okMsg, onOk } =
    div
        [ css
            [ position fixed
            , zIndex (int 20)
            , top (vh 50)
            , left (pct 50)
            , padding2 (px 20) (px 40)
            , backgroundColor Style.theme.bg2
            , border3 (px 5) solid Style.theme.ac2
            , borderRadius (px 20)
            , transform (translate2 (pct -50) (pct -50))
            ]
        ]
        [ h3 [] [ text header ]
        , body
        , div
            [ css
                [ marginTop (px 20)
                , displayFlex
                , justifyContent end
                ]
            ]
            [ Style.btnBordered
                [ onClick onCancel
                , css [ hover [ backgroundColor Style.theme.ac2 ] ]
                ]
                [ text cancelMsg ]
            , Style.btnBordered
                [ onClick onOk
                , css
                    [ marginLeft (px 20)
                    , hover [ backgroundColor Style.theme.ac2 ]
                    ]
                ]
                [ text okMsg ]
            ]
        ]


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


onClickStopProp : msg -> Html.Attribute msg
onClickStopProp m =
    stopPropagationOn "click" (Json.Decode.succeed ( m, True ))
