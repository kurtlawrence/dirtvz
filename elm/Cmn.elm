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


dropdown : Html a -> List (Html a) -> Html a
dropdown display items =
    div
        [ Attr.tabindex 0
        , Attr.class Style.class.dropdown
        ]
        [ div
            [ css
                [ padding2 (px 1) (px 3)
                , textAlign center
                , borderBottom3 (px 1) solid Style.theme.ac1
                , cursor pointer
                , hover
                    [ backgroundColor Style.theme.bg2
                    ]
                ]
            ]
            [ display ]
        , div
            [ Attr.tabindex -1
            , Attr.class Style.class.dropdownItems
            ]
          <|
            List.map
                (\x ->
                    div
                        [ css
                            [ padding2 (px 2) (px 10)
                            , hover
                                [ backgroundColor Style.theme.ac2
                                , cursor
                                    default
                                ]
                            ]
                        ]
                        [ x ]
                )
                items
        ]


namedColourDropdown : String -> (String -> a) -> Html a
namedColourDropdown current onChoose =
    let
        cv attr c =
            div
                (attr
                    ++ [ css
                            [ displayFlex
                            , alignItems center
                            , fontSize (Css.em 0.8)
                            , width (px 170)
                             ]
                       ]
                )
                [ div
                    [ css
                        [ property "background" c
                        , width (px 16)
                        , height (px 8)
                        , margin2 (px 3) (px 5)
                        , border3 (px 1) solid (rgb 0 0 0)
                        ]
                    ]
                    []
                , text c
                ]
    in
    htmlColours
        |> List.map (\x -> cv [ onClick (onChoose x) ] x)
        |> dropdown (cv [] current)


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



-- MISC


htmlColours : List String
htmlColours =
    [ "white"
    , "transparent"
    , "whitesmoke"
    , "gainsboro"
    , "lightgray"
    , "silver"
    , "darkgray"
    , "gray"
    , "dimgray"
    , "black"
    , "snow"
    , "azure"
    , "ivory"
    , "honeydew"
    , "ghostwhite"
    , "aliceblue"
    , "floralwhite"
    , "lavender"
    , "lightsteelblue"
    , "lightslategray"
    , "slategray"
    , "mintcream"
    , "seashell"
    , "papayawhip"
    , "oldlace"
    , "linen"
    , "lavenderblush"
    , "mistyrose"
    , "peachpuff"
    , "navajowhite"
    , "moccasin"
    , "rosybrown"
    , "tan"
    , "burlywood"
    , "sandybrown"
    , "peru"
    , "chocolate"
    , "sienna"
    , "saddlebrown"
    , "lightyellow"
    , "lightgoldenrodyellow"
    , "lemonchiffon"
    , "cornsilk"
    , "wheat"
    , "blanchedalmond"
    , "bisque"
    , "beige"
    , "antiquewhite"
    , "pink"
    , "lightpink"
    , "hotpink"
    , "deeppink"
    , "palevioletred"
    , "mediumvioletred"
    , "orchid"
    , "fuchsia"
    , "violet"
    , "plum"
    , "thistle"
    , "purple"
    , "mediumorchid"
    , "darkorchid"
    , "darkviolet"
    , "darkmagenta"
    , "mediumpurple"
    , "mediumslateblue"
    , "slateblue"
    , "darkslateblue"
    , "indigo"
    , "blueviolet"
    , "royalblue"
    , "blue"
    , "mediumblue"
    , "darkblue"
    , "navy"
    , "midnightblue"
    , "lightskyblue"
    , "skyblue"
    , "lightblue"
    , "dodgerblue"
    , "deepskyblue"
    , "cornflowerblue"
    , "steelblue"
    , "cadetblue"
    , "powderblue"
    , "aquamarine"
    , "paleturquoise"
    , "mediumturquoise"
    , "turquoise"
    , "darkturquoise"
    , "lightcyan"
    , "cyan"
    , "aqua"
    , "darkcyan"
    , "teal"
    , "darkslategray"
    , "lightseagreen"
    , "mediumseagreen"
    , "mediumaquamarine"
    , "seagreen"
    , "springgreen"
    , "mediumspringgreen"
    , "darkseagreen"
    , "palegreen"
    , "lightgreen"
    , "limegreen"
    , "lime"
    , "forestgreen"
    , "green"
    , "darkgreen"
    , "greenyellow"
    , "chartreuse"
    , "lawngreen"
    , "olivedrab"
    , "darkolivegreen"
    , "yellowgreen"
    , "yellow"
    , "olive"
    , "khaki"
    , "darkkhaki"
    , "palegoldenrod"
    , "goldenrod"
    , "darkgoldenrod"
    , "gold"
    , "orange"
    , "darkorange"
    , "orangered"
    , "lightsalmon"
    , "salmon"
    , "darksalmon"
    , "lightcoral"
    , "indianred"
    , "coral"
    , "tomato"
    , "red"
    , "crimson"
    , "firebrick"
    , "brown"
    , "darkred"
    , "maroon"
    ]
