port module Progress exposing (..)

import Cmn
import Css exposing (..)
import Html.Styled exposing (..)
import Html.Styled.Attributes exposing (css, href, src)
import Html.Styled.Events exposing (onClick)


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


viewBar : Bool -> Progress -> Html a
viewBar showMsg { msg, iter, outof } =
    div [ css [ width (pct 100), height (Css.em 1) ] ]
        [ span [] <|
            if showMsg then
                [ text msg ]

            else
                []
        , div
            [ css
                [ width (pct <| toFloat iter / toFloat outof * 100)
                , height (pct 100)
                , backgroundColor Cmn.theme.primary1
                ]
            ]
            []
        ]
