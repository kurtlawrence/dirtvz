module ViewerUI exposing (..)

import Browser
import Css exposing (..)
import Html.Styled as H exposing (..)
import Html.Styled.Attributes as A exposing (css)
import Html.Styled.Events exposing (..)
import Notice
import Ports exposing (HoverInfo)
import Progress exposing (Progress)
import SpatialObject exposing (SpatialObject)



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
    , objList : List SpatialObject
    , hoverInfo : Maybe HoverInfo
    }


type Msg
    = Notice Notice.Notice
    | PickSpatialFile
    | RecvObjectList (List SpatialObject)
    | DeleteObject ObjKey
    | ToggleLoaded ObjKey
    | RecvHoverInfo (Maybe HoverInfo)
    | RecvProgress Progress


type alias Flags =
    ()


type alias Html =
    H.Html Msg


type alias ObjKey =
    String


init : Flags -> ( Model, Cmd Msg )
init _ =
    ( { notice = Notice.None
      , objList = []
      , hoverInfo = Nothing
      }
    , Cmd.none
    )



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Notice n ->
            ( { model | notice = n }, Cmd.none )

        PickSpatialFile ->
            ( model, Ports.pick_spatial_file () )

        RecvObjectList list ->
            ( { model | objList = list }, Cmd.none )

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
                    ( { model | objList = SpatialObject.setProgress p key model.objList }, Cmd.none )

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
        , SpatialObject.objectList RecvObjectList
        , Ports.hoverInfo RecvHoverInfo
        , Progress.recv_progress RecvProgress
        ]



-- VIEW


view : Model -> Html
view model =
    div []
        [ div []
            [ text "Hello from Elm land" ]
        , div []
            [ node "dirtvis-viewer"
                [ css [ display block, width (px 500), height (px 500) ]
                ]
                []
            ]
        , div [] [ objectListView model.objList ]
        , div [] [ button [ onClick PickSpatialFile ] [ text "Add spatial object" ] ]
        , div [] [ Maybe.map hoverInfoView model.hoverInfo |> Maybe.withDefault (div [] []) ]
        , div [] [ noticeView model.notice ]
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
