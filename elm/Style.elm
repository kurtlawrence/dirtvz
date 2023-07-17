module Style exposing (..)

import Css exposing (..)
import Css.Global
import Css.Transitions exposing (transition)
import FontAwesome
import FontAwesome.Attributes
import FontAwesome.Regular
import FontAwesome.Solid
import Html.Styled as Html exposing (..)
import Html.Styled.Attributes as Attr exposing (css)
import Html.Styled.Events exposing (..)
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
    , dropdown = "dropdown"
    , dropdownItems = "items"
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

    -- text input
    , Css.Global.selector "input[type=text]"
        [ property "background" "none"
        , border3 (px 1) solid theme.ac2
        , borderRadius (vh 50)
        , margin (px 2)
        , padding2 (px 2) (px 10)
        , fontSize (Css.em 0.8)
        , display inlineBlock
        , pseudoClass "focus-visible"
            [ outline3 (px 1) solid theme.ac2
            , borderColor theme.ac1
            ]
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
    , Css.Global.everything
        [ property "scrollbar-width" "thin" ]

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

    -- dropdown
    , Css.Global.class class.dropdown
        [ minWidth (px 80)
        , position relative
        , Css.Global.descendants
            [ Css.Global.class class.dropdownItems
                [ height zero
                , position absolute
                , backgroundColor theme.bg1
                , overflow hidden
                , whiteSpace noWrap
                , zIndex (int 10)
                , opacity zero
                , maxHeight (px 400)
                , overflowY auto
                , boxSizing borderBox
                , width (pct 100)
                , transition [ Css.Transitions.opacity 100 ]
                ]
            ]
        , focus
            [ Css.Global.descendants
                [ Css.Global.class class.dropdownItems
                    [ height unset
                    , opacity (num 1)
                    , border3 (px 1) solid theme.ac1
                    , borderTop zero
                    ]
                ]
            ]
        , pseudoClass "focus-within"
            [ Css.Global.descendants
                [ Css.Global.class class.dropdownItems
                    [ height unset
                    , opacity (num 1)
                    , border3 (px 1) solid theme.ac1
                    , borderTop zero
                    ]
                ]
            ]
        ]
    ]


panelBorders : List Style
panelBorders =
    [ marginRight (px 5)
    , padding (px 5)
    , borderRadius4 zero (px 5) (px 5) zero
    , boxShadow5 (px 3) zero (px 5) (px -3) theme.ac1
    ]


panel1 : Html msg -> Html msg
panel1 child =
    div
        [ Attr.id "panel-1"
        , css <|
            [ minWidth (px 200)
            , resize horizontal
            , overflow hidden
            ]
                ++ panelBorders
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


type IconSize
    = FaDefault
    | FaXs
    | FaSm
    | FaLg


defIconAttrs =
    [ Svg.Attributes.style "margin: auto" ]


ico : FontAwesome.Icon FontAwesome.WithoutId -> IconSize -> Html msg
ico icon size =
    let
        sz =
            case size of
                FaDefault ->
                    FontAwesome.Attributes.sm

                FaXs ->
                    FontAwesome.Attributes.xs

                FaSm ->
                    FontAwesome.Attributes.sm

                FaLg ->
                    FontAwesome.Attributes.lg
    in
    icon
        |> FontAwesome.styled [ sz, Svg.Attributes.style "margin: auto" ]
        |> FontAwesome.view
        |> fromUnstyled


iconPen : IconSize -> Html msg
iconPen =
    ico FontAwesome.Solid.pen


iconTrash : IconSize -> Html msg
iconTrash =
    ico FontAwesome.Solid.trash


iconFileImport : IconSize -> Html msg
iconFileImport =
    ico FontAwesome.Solid.fileImport


iconFolderPlus : IconSize -> Html msg
iconFolderPlus =
    ico FontAwesome.Solid.folderPlus


iconObjectRoot : IconSize -> Html msg
iconObjectRoot =
    ico FontAwesome.Regular.objectUngroup


iconQuestionMark : IconSize -> Html msg
iconQuestionMark =
    ico FontAwesome.Solid.question


iconSurface : IconSize -> Html msg
iconSurface =
    ico FontAwesome.Solid.mountain


iconFolderClosed : IconSize -> Html msg
iconFolderClosed =
    ico FontAwesome.Solid.folder


iconFolderOpen : IconSize -> Html msg
iconFolderOpen =
    ico FontAwesome.Solid.folderOpen


iconFolderMove : IconSize -> Html msg
iconFolderMove =
    ico FontAwesome.Solid.upDownLeftRight


iconLoadedFilterToggle : IconSize -> Html msg
iconLoadedFilterToggle =
    ico FontAwesome.Solid.eye


iconSolidEye : IconSize -> Html msg
iconSolidEye =
    ico FontAwesome.Solid.eye


iconEmptyEye : IconSize -> Html msg
iconEmptyEye =
    ico FontAwesome.Regular.eye


iconGear : IconSize -> Html msg
iconGear =
    ico FontAwesome.Solid.gear
