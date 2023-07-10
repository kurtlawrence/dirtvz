module ViewerUI exposing (..)

import Browser
import FontAwesome.Styles
import Css exposing (..)
import Html.Styled as H exposing (..)
import Html.Styled.Attributes as A exposing (css)
import Html.Styled.Events exposing (..)
import Notice
import ObjectTree exposing (ObjectTree)
import Ports exposing (HoverInfo)
import Progress exposing (Progress)
import SpatialObject exposing (SpatialObject)
import Style
import Css.Global 



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
    , objs : ObjectTree
    , hoverInfo : Maybe HoverInfo
    }


type Msg
    = Notice Notice.Notice
    | PickSpatialFile
    | DeleteObject ObjKey
    | ToggleLoaded ObjKey
    | RecvHoverInfo (Maybe HoverInfo)
    | RecvProgress Progress
    | ObjectTreeMsg ObjectTree.Msg


type alias Flags =
    ()


type alias Html =
    H.Html Msg


type alias ObjKey =
    String


init : Flags -> ( Model, Cmd Msg )
init _ =
    ( { notice = Notice.None
      , hoverInfo = Nothing
      , objs = ObjectTree.empty
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

        ToggleLoaded key ->
            ( model, Ports.toggle_loaded key )

        RecvHoverInfo info ->
            ( { model | hoverInfo = info }, Cmd.none )

        RecvProgress p ->
            case Progress.decode p of
                Progress.Preprocessing key ->
                    ObjectTree.update (ObjectTree.SetProgress p key) model.objs
                        |> liftUpdate ObjectTreeMsg (\x -> { model | objs = x })

                Progress.Unknown ->
                    ( model, Cmd.none )


liftUpdate : (b -> Msg) -> (a -> Model) -> ( a, Cmd b ) -> ( Model, Cmd Msg )
liftUpdate toMsg toModel =
    Tuple.mapBoth toModel (Cmd.map toMsg)



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ Notice.get_notice (Notice.recv Notice)
        , SpatialObject.objectList ObjectTree.RecvSpatialObjects
            |> Sub.map ObjectTreeMsg
        , Ports.hoverInfo RecvHoverInfo
        , Progress.recv_progress RecvProgress
        ]



-- VIEW


view : Model -> Html
view model =
    div
        [ A.style "height" "100%"
        , A.style "display" "flex"
        , A.style "box-sizing" "border-box"
        , css [ backgroundColor Style.theme.bg1 ]
        ]
        [ Css.Global.global Style.globalCss
        , FontAwesome.Styles.css |> fromUnstyled
        , div [ css [ displayFlex ] ]
            [ Style.panel1 <|
                (ObjectTree.view model.objs |> H.map ObjectTreeMsg)
            ]
        , div []
            [ node "dirtvz-viewer"
                [ css
                    [ displayFlex
                    , flex3 (int 1) (int 1) (px 500)
                    , minWidth (px 500)
                    , minHeight (px 500)
                    ]
                ]
                []
            ]
        ]


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
                    , button [ onClick (ToggleLoaded x.key) ] [ text "load/unload" ]
                    ]
                , maybeProgBar x
                ]
        )
        >> div []


maybeProgBar : SpatialObject -> Html
maybeProgBar { status, prg } =
    case ( status, prg ) of
        ( "preprocessing", Just p ) ->
            div [] [ Progress.viewBar False p ]

        _ ->
            div [] []


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
