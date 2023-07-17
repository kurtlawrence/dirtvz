port module Settings exposing (..)

import Cmn
import Css exposing (..)
import Html.Styled as Html exposing (..)
import Html.Styled.Attributes as Attr exposing (css)
import Html.Styled.Events exposing (..)
import List.Extra as Listx
import Platform.Cmd as Cmd
import Style


type alias Settings =
    { bg : Background
    , render : RenderOptions
    }


type alias Changes =
    { bg : Bool
    , render : Bool
    }


noChg : Changes
noChg =
    { bg = False
    , render = False
    }


type alias Model =
    { settings : Settings
    }


type Msg
    = BgSetType String
    | BgAddColour
    | BgSetColour Int String
    | BgRemoveColour Int
    | RenderSetMsaa Int


with : Settings -> Model
with s =
    { settings = s }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        BgSetType x ->
            uBg model (\bg -> { bg | ty = x })
                |> updateViewer { noChg | bg = True }

        BgAddColour ->
            uBg model
                (\bg ->
                    { bg | colours = bg.colours ++ [ "oldlace" ] }
                )
                |> updateViewer { noChg | bg = True }

        BgSetColour i c ->
            uBg model
                (\bg ->
                    { bg
                        | colours = Listx.setAt i c bg.colours
                    }
                )
                |> updateViewer { noChg | bg = True }

        BgRemoveColour i ->
            if List.length model.settings.bg.colours <= 1 then
                ( model, Cmd.none )

            else
                uBg model
                    (\bg ->
                        { bg
                            | colours = Listx.removeAt i bg.colours
                        }
                    )
                    |> updateViewer { noChg | bg = True }

        RenderSetMsaa i ->
            uRender model
                (\r -> { r | msaa = i })
                |> updateViewer { noChg | render = True }


us : Model -> (Settings -> Settings) -> Model
us m sf =
    { m | settings = sf m.settings }


uBg : Model -> (Background -> Background) -> Model
uBg m f =
    us m (\s -> { s | bg = f s.bg })


uRender : Model -> (RenderOptions -> RenderOptions) -> Model
uRender m f =
    us m (\s -> { s | render = f s.render })


updateViewer : Changes -> Model -> ( Model, Cmd a )
updateViewer c m =
    ( m, settings_changed { settings = m.settings, changes = c } )



-- PORTS


port settings_changed : { settings : Settings, changes : Changes } -> Cmd a



-- VIEW


view : Model -> Html Msg
view { settings } =
    div []
        [ Html.em [] [ text "Background" ]
        , hr
        , viewBg settings.bg
        , Html.em [] [ text "Rendering" ]
        , hr
        , viewRenderOpts settings.render
        ]


hr : Html msg
hr =
    Html.hr
        [ css
            [ marginTop (Css.em 0.1)
            , color Style.theme.bg2
            , opacity (num 0.5)
            ]
        ]
        []



-- BACKGROUND


type alias Background =
    { ty : String
    , colours : List String
    }


viewBg : Background -> Html Msg
viewBg { ty, colours } =
    let
        cs =
            (if ty == "single" then
                List.take 1 colours

             else
                colours
            )
                |> List.indexedMap
                    (\i c ->
                        div [ css [ displayFlex ] ]
                            [ button [ Attr.title "Remove", onClick (BgRemoveColour i) ]
                                [ Style.iconTrash Style.FaXs ]
                            , Cmn.namedColourDropdown
                                c
                                (BgSetColour i)
                            ]
                    )
    in
    [ button [ onClick BgAddColour ] [ text "add colour" ] ]
        |> (++) cs
        |> (::)
            (div [ css [ alignSelf start ] ]
                [ Cmn.dropdown (text ty) <|
                    List.map (\t -> div [ onClick (BgSetType t) ] [ text t ]) <|
                        [ "single", "linear", "radial" ]
                ]
            )
        |> div
            [ css
                [ displayFlex
                , flexDirection column
                , alignItems end
                , fontSize (Css.em 0.9)
                ]
            ]



-- RENDER OPTIONS


type alias RenderOptions =
    { msaa : Int
    }


viewRenderOpts : RenderOptions -> Html Msg
viewRenderOpts { msaa } =
    let
        v x =
            "MSAA "
                ++ String.fromInt x
                ++ "x"
                |> text

        vs =
            List.map (\n -> div [ onClick (RenderSetMsaa n) ] [ v n ])
    in
    div [ css [ fontSize (Css.em 0.9) ] ]
        [ div [ css [ displayFlex, justifyContent spaceBetween ] ]
            [ text "Anti-aliasing"
            , Cmn.dropdown (v msaa) (vs [ 1, 2, 4, 8 ])
            ]
        ]
