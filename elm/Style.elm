module Style exposing (..)

import Css exposing (..)
import Css.Global
import FontAwesome
import FontAwesome.Solid
import FontAwesome.Attributes
import Html.Styled as Html exposing (..)
import Html.Styled.Attributes as Attr exposing (css)
import Html.Styled.Events exposing (..)


type alias Theme =
    { bg1 : Color
    , bg2 : Color
    , ac2 : Color
    , ac1 : Color
    }


theme : Theme
theme =
    { bg1 = rgb 245 245 245
    , bg2 = rgb 242 234 211
    , ac2 = rgb 223 215 191
    , ac1 = rgb 63 35 5
    }


class =
    { displayOnParentHover = "display-on-parent-hover"
    }


globalCss : List Css.Global.Snippet
globalCss =
    [ Css.Global.button [ all unset ]

    -- title attribute
    , Css.Global.selector "*[title]:hover::after"
        [ property "content" "attr(title)"
        , position absolute
        , textAlign center
        , fontSize (Css.em 0.5)
        , padding2 (px 2) (px 4)
        , backgroundColor theme.ac1
        , color theme.bg1
        , borderRadius (px 4)
        , transform (translateX (px 10))
        , transform (translateY (pct -50))
        ]

    -- display-on-parent-hover class
    , Css.Global.class class.displayOnParentHover [ visibility hidden ]
    , Css.Global.everything
        [ hover
            [ Css.Global.children
                [ Css.Global.class class.displayOnParentHover
                    [ visibility visible ]
                ]
            ]
        ]
    ]


panel1 : Html msg -> Html msg
panel1 child =
    div
        [ Attr.id "panel-1"
        , css
            [ minWidth (px 200)
            , resize horizontal
            , overflow hidden
            , margin (px 5)
            , padding (px 5)
            , borderRadius (px 5)
            , boxShadow5 (px 0) (px 0) (px 5) (px 1) theme.ac1
            ]
        ]
        [ child ]


button : List (Attribute msg) -> List (Html msg) -> Html msg
button =
    styled
        Html.button
        [ color theme.ac1
        , opacity (num 0.5)
        , cursor pointer
        , hover [ opacity (num 1) ]
        ]


iconPen : Html msg
iconPen =
    FontAwesome.Solid.pen
        |> FontAwesome.styled [ FontAwesome.Attributes.sm ]
        |> FontAwesome.view
        |> fromUnstyled
