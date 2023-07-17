port module ViewerUI exposing (..)

import Browser
import Css exposing (..)
import Css.Global
import FontAwesome.Styles
import Html.Styled as H exposing (..)
import Html.Styled.Attributes as A exposing (css)
import Html.Styled.Events exposing (..)
import Html.Styled.Lazy as Lazy
import Nav
import Notice
import ObjectTree exposing (ObjectTree)
import Ports exposing (HoverInfo)
import Progress exposing (Progress)
import Settings
import SpatialObject exposing (SpatialObject)
import Style



-- MAIN


main : Program Flags Model Msg
main =
    Browser.element
        { init = init
        , subscriptions = subscriptions
        , update = update
        , view = view >> toUnstyled
        }



-- MODEL


type alias Model =
    { notice : Notice.Notice
    , nav : Nav.State
    , objs : ObjectTree
    , hoverInfo : Maybe HoverInfo
    , settings : Settings.Model
    }


type Msg
    = Notice Notice.Notice
    | PickSpatialFile
    | DeleteObject ObjKey
    | RecvHoverInfo (Maybe HoverInfo)
    | RecvProgress Progress
    | ObjectTreeMsg ObjectTree.Msg
    | SetNavState Nav.State
    | SettingsMsg Settings.Msg


type alias Flags =
    { settings : Settings.Settings
    , object_tree : Maybe ObjectTree.FlatTree
    }


type alias Html =
    H.Html Msg


type alias ObjKey =
    String


init : Flags -> ( Model, Cmd Msg )
init { object_tree, settings } =
    ( { notice = Notice.None
      , nav = Nav.Objects
      , hoverInfo = Nothing
      , settings = Settings.with settings
      , objs =
            case object_tree of
                Just x ->
                    ObjectTree.withFlatTree x ObjectTree.empty

                Nothing ->
                    ObjectTree.empty
      }
    , Cmd.none
    )



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Notice n ->
            ( { model | notice = n }, Cmd.none )

        ObjectTreeMsg m ->
            ObjectTree.update m model.objs
                |> liftUpdate ObjectTreeMsg (\x -> { model | objs = x })

        PickSpatialFile ->
            ( model, Ports.pick_spatial_file () )

        DeleteObject key ->
            ( model
            , Cmd.batch
                [ Ports.delete_spatial_object key
                , Notice.waiting Notice ("Deleting '" ++ key ++ "' from database")
                ]
            )

        RecvHoverInfo info ->
            ( { model | hoverInfo = info }, Cmd.none )

        RecvProgress p ->
            case Progress.decode p of
                Progress.Preprocessing key ->
                    ObjectTree.update (ObjectTree.SetProgress { p | msg = "Preprocessing" } key) model.objs
                        |> liftUpdate ObjectTreeMsg (\x -> { model | objs = x })

                Progress.Unknown ->
                    ( model, Cmd.none )

        SetNavState s ->
            ( { model | nav = s }, hint_canvas_resize () )

        SettingsMsg m ->
            Settings.update m model.settings
                |> liftUpdate SettingsMsg (\x -> { model | settings = x })


liftUpdate : (b -> Msg) -> (a -> Model) -> ( a, Cmd b ) -> ( Model, Cmd Msg )
liftUpdate toMsg toModel =
    Tuple.mapBoth toModel (Cmd.map toMsg)



-- SUBSCRIPTIONS


port merge_object_flat_tree : (ObjectTree.FlatTree -> msg) -> Sub msg


port hint_canvas_resize : () -> Cmd msg


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ Notice.get_notice (Notice.recv Notice)
        , Ports.hoverInfo RecvHoverInfo
        , Progress.recv_progress RecvProgress

        -- ObjectTree
        , Sub.batch
            [ SpatialObject.objectList ObjectTree.RecvSpatialObjects
            , merge_object_flat_tree ObjectTree.MergeFlatTree
            ]
            |> Sub.map ObjectTreeMsg
        ]



-- VIEW


view : Model -> Html
view model =
    div
        [ A.style "height" "100%"
        , A.style "display" "flex"
        , css [ backgroundColor Style.theme.bg1 ]
        ]
        [ Css.Global.global Style.globalCss
        , FontAwesome.Styles.css |> fromUnstyled
        , div [ css [ displayFlex ] ]
            [ Lazy.lazy (Nav.view SetNavState) model.nav
            , panel1 model
            ]
        , div [ css [ flex (int 1) ] ]
            [ node "dirtvz-viewer"
                [ css
                    [ display block
                    , height (pct 100)
                    , width (pct 100)
                    ]
                ]
                []
            ]
        ]


panel1 : Model -> Html
panel1 model =
    case model.nav of
        Nav.None ->
            div [] []

        Nav.Objects ->
            Lazy.lazy ObjectTree.view model.objs
                |> H.map ObjectTreeMsg
                |> Style.panel1

        Nav.Settings ->
            Lazy.lazy Settings.view model.settings
                |> H.map SettingsMsg
                |> Style.panel1


noticeView notice =
    case notice of
        Notice.None ->
            text ""

        Notice.Ok x ->
            text ("✅ Ok: " ++ x)

        Notice.Err x ->
            text ("❌ Err: " ++ x)

        Notice.Waiting x ->
            text ("⏳ Waiting: " ++ x)


objectListView : List SpatialObject -> Html
objectListView =
    List.map
        (\x ->
            div []
                [ div []
                    [ strong [] [ text x.key ]
                    , H.em [] [ text x.status ]
                    , button [ onClick (DeleteObject x.key) ] [ text "delete" ]
                    ]
                ]
        )
        >> div []


hoverInfoView : HoverInfo -> Html
hoverInfoView info =
    let
        { pointerx, pointery, renderPt, worldPt } =
            info
    in
    div []
        [ hr [] []
        , div [] [ text <| "screen coordinates: (" ++ String.fromInt pointerx ++ "," ++ String.fromInt pointery ++ ")" ]
        , div [] <|
            case renderPt of
                Just p ->
                    [ text <| "render coordinates: " ++ p3toString p ]

                Nothing ->
                    []
        , div [] <|
            case worldPt of
                Just p ->
                    [ text <| "world coordinates: " ++ p3toString p ]

                Nothing ->
                    []
        , div [] [ text <| decomposeMeshInfo info ]
        , hr [] []
        ]


p3toString { x, y, z } =
    "(" ++ String.fromFloat x ++ "," ++ String.fromFloat y ++ "," ++ String.fromFloat z ++ ")"


decomposeMeshInfo { meshName, tileId, lodRes } =
    case ( meshName, tileId, lodRes ) of
        ( Just n, Just id, Just res ) ->
            "closest mesh: { key = "
                ++ n
                ++ ", tile = "
                ++ String.fromInt id
                ++ ", lod = "
                ++ String.fromFloat res
                ++ "m }"

        _ ->
            ""
