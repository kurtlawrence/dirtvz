module Style exposing (..)

import Css exposing (..)
import Css.Global
import FontAwesome
import FontAwesome.Attributes
import FontAwesome.Regular
import FontAwesome.Solid
import Html.Styled as Html exposing (..)
import Html.Styled.Attributes as Attr exposing (css)
import Html.Styled.Events exposing (..)
import Svg
import Svg.Attributes


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
    [ Css.Global.button
        [ all unset
        , color theme.ac1
        , opacity (num 0.5)
        , cursor pointer
        , backgroundColor theme.bg1
        , borderRadius (px 3)
        , hover [ opacity (num 1), backgroundColor theme.bg2 ]
        , pseudoClass "focus-visible" [ opacity (num 1) ]
        ]

    -- code
    , Css.Global.code
        [ backgroundColor theme.ac2
        , padding2 (px 3) (px 5)
        , borderRadius (px 5)
        , fontSize (Css.em 0.9)
        , fontFamilies [ "Fira Code", "monospace" ]
        ]

    -- pre
    , Css.Global.pre
        [ backgroundColor theme.ac2
        , padding2 (px 3) (px 5)
        , borderRadius (px 5)
        , Css.Global.children
            [ Css.Global.code
                [ whiteSpace preWrap
                , padding unset
                ]
            ]
        ]

    -- title attribute
    , Css.Global.selector "*[title]:hover::after"
        [ property "content" "attr(title)"
        , position absolute
        , textAlign center
        , fontSize (Css.rem 0.6)
        , padding2 (px 2) (px 4)
        , backgroundColor theme.ac1
        , color theme.bg1
        , borderRadius (px 4)
        , transform (translateX (px 10))
        , transform (translateY (pct -50))
        , zIndex (int 1)
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


btnBordered : List (Attribute msg) -> List (Html msg) -> Html msg
btnBordered =
    styled
        Html.button
        [ border3 (px 1) solid theme.ac1
        , padding2 (px 3) (px 5)
        , lineHeight (Css.em 1)
        ]


checkbox : List (Attribute msg) -> Html msg
checkbox attrs =
    styled
        Html.input
        []
        (Attr.type_ "checkbox" :: attrs)
        []


defIconAttrs =
    [ FontAwesome.Attributes.sm
    , Svg.Attributes.style "margin: auto"
    ]


iconPen : List (Svg.Attribute Never) -> Html msg
iconPen attrs =
    FontAwesome.Solid.pen
        |> FontAwesome.styled (defIconAttrs ++ attrs)
        |> FontAwesome.view
        |> fromUnstyled


iconTrash : List (Svg.Attribute Never) -> Html msg
iconTrash attrs =
    FontAwesome.Solid.trash
        |> FontAwesome.styled (defIconAttrs ++ attrs)
        |> FontAwesome.view
        |> fromUnstyled


iconFileImport : List (Svg.Attribute Never) -> Html msg
iconFileImport attrs =
    FontAwesome.Solid.fileImport
        |> FontAwesome.styled (defIconAttrs ++ attrs)
        |> FontAwesome.view
        |> fromUnstyled


iconFolderPlus : List (Svg.Attribute Never) -> Html msg
iconFolderPlus attrs =
    FontAwesome.Solid.folderPlus
        |> FontAwesome.styled (defIconAttrs ++ attrs)
        |> FontAwesome.view
        |> fromUnstyled


iconObjectRoot : List (Svg.Attribute Never) -> Html msg
iconObjectRoot attrs =
    FontAwesome.Regular.objectUngroup
        |> FontAwesome.styled (defIconAttrs ++ attrs)
        |> FontAwesome.view
        |> fromUnstyled


iconQuestionMark : List (Svg.Attribute Never) -> Html msg
iconQuestionMark attrs =
    FontAwesome.Solid.question
        |> FontAwesome.styled (defIconAttrs ++ attrs)
        |> FontAwesome.view
        |> fromUnstyled


iconSurface : List (Svg.Attribute Never) -> Html msg
iconSurface attrs =
    FontAwesome.Solid.mountain
        |> FontAwesome.styled (defIconAttrs ++ attrs)
        |> FontAwesome.view
        |> fromUnstyled


iconFolderClosed : List (Svg.Attribute Never) -> Html msg
iconFolderClosed attrs =
    FontAwesome.Solid.folder
        |> FontAwesome.styled (defIconAttrs ++ attrs)
        |> FontAwesome.view
        |> fromUnstyled


iconFolderOpen : List (Svg.Attribute Never) -> Html msg
iconFolderOpen attrs =
    FontAwesome.Solid.folderOpen
        |> FontAwesome.styled (defIconAttrs ++ attrs)
        |> FontAwesome.view
        |> fromUnstyled
