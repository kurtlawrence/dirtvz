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
    }


type alias Changes =
    { bg : Bool
    }


noChg : Changes
noChg =
    { bg = False
    }


type alias Model =
    { settings : Settings
    }


type Msg
    = BgSetType String
    | BgAddColour
    | BgSetColour Int String
    | BgRemoveColour Int


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


us : Model -> (Settings -> Settings) -> Model
us m sf =
    { m | settings = sf m.settings }


uBg : Model -> (Background -> Background) -> Model
uBg m f =
    us m (\s -> { s | bg = f s.bg })


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
        ]


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
                ]
            ]
