port module Progress exposing (..)

import Cmn
import Css exposing (..)
import Html.Styled exposing (..)
import Html.Styled.Attributes exposing (css, title)
import Html.Styled.Events exposing (onClick)
import Style


type alias Progress =
    { msg : String
    , iter : Int
    , outof : Int
    }


type For
    = Unknown
    | Preprocessing String


port recv_progress : (Progress -> msg) -> Sub msg


decode : Progress -> For
decode { msg } =
    case String.split "/" msg of
        "preprocessing" :: xs ->
            Preprocessing (String.join "/" xs)

        _ ->
            Unknown


viewBar : Progress -> Html a
viewBar { msg, iter, outof } =
    div
        (css [ width (pct 100), height (px 4), backgroundColor Style.theme.ac2 ]
            :: (if String.isEmpty msg then
                    []

                else
                    [ title msg ]
               )
        )
        [ div
            [ css
                [ width (pct <| toFloat iter / toFloat outof * 100)
                , height (pct 100)
                , backgroundColor Style.theme.ac1
                ]
            ]
            []
        ]
