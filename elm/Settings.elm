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
    , light: LightingOptions
    }


type alias Changes =
    { bg : Bool
    , render : Bool
    , light: Bool
    }


noChg : Changes
noChg =
    { bg = False
    , render = False
    , light = False
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
    | RenderToggleWorldAxes
    | LightSetBearing Float
    | LightSetSlope Float


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

        RenderToggleWorldAxes ->
            uRender model
                (\r -> { r | worldaxes = not r.worldaxes })
                |> updateViewer { noChg | render = True }

        LightSetBearing x ->
            uLight model
                (\l -> { l | bearing = x })
                |> updateViewer { noChg | light = True }

        LightSetSlope x ->
            uLight model
                (\l -> { l | slope = x })
                |> updateViewer { noChg | light = True }


us : Model -> (Settings -> Settings) -> Model
us m sf =
    { m | settings = sf m.settings }


uBg : Model -> (Background -> Background) -> Model
uBg m f =
    us m (\s -> { s | bg = f s.bg })


uRender : Model -> (RenderOptions -> RenderOptions) -> Model
uRender m f =
    us m (\s -> { s | render = f s.render })

uLight : Model -> (LightingOptions -> LightingOptions) -> Model
uLight m f =
    us m (\s -> { s | light = f s.light })


updateViewer : Changes -> Model -> ( Model, Cmd a )
updateViewer c m =
    ( m, settings_changed { settings = m.settings, changes = c } )



-- PORTS


port settings_changed : { settings : Settings, changes : Changes } -> Cmd a



-- VIEW


view : Model -> Html Msg
view { settings } =
    let
       hd =
          css [ display block, textDecoration underline, marginBottom (Css.em 0.7) ]
    in
    div []
        [ Html.em [hd] [ text "Background" ]
        , viewBg settings.bg
        , hr
        , Html.em [hd] [ text "Rendering" ]
        , viewRenderOpts settings.render
        , hr
        , Html.em [hd] [ text "Lighting" ]
        , viewLighting settings.light
        ]


hr : Html msg
hr =
    Html.hr
        [ css
            [ color Style.theme.bg2
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
    , worldaxes : Bool
    }


viewRenderOpts : RenderOptions -> Html Msg
viewRenderOpts { msaa, worldaxes } =
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
        , button
            [ css
                [ opacity (num 1)
                , marginTop (px 5)
                , padding (px 3)
                ]
            , onClick RenderToggleWorldAxes
            ]
            [ Style.checkbox [ Attr.checked worldaxes ], text "Show World Axes" ]
        ]


-- LIGHTING OPTIONS


type alias LightingOptions =
    { bearing : Float
    , slope : Float
    }


viewLighting : LightingOptions -> Html Msg
viewLighting { bearing, slope } =
    div [ css [ fontSize (Css.em 0.9) ] ]
        [ div [ css [ displayFlex, justifyContent spaceBetween ] ]
            [ text "Bearing"
            , Cmn.sliderInput [] (0, 360) bearing LightSetBearing
            ]
        , div [ css [ displayFlex, justifyContent spaceBetween ] ]
            [ text "Slope"
            , Cmn.sliderInput [] (0, 90) slope LightSetSlope
            ]
        ]