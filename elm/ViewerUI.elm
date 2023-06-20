module ViewerUI exposing (..)

import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Notice
import Ports exposing (HoverInfo)
import SpatialObject exposing (SpatialObject)



-- MAIN


main : Program Flags Model Msg
main =
    Browser.element
        { init = init
        , subscriptions = subscriptions
        , update = update
        , view = view
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


type alias Flags =
    ()


type alias Html =
    Html.Html Msg


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
            ( model, Ports.pickSpatialFile () )

        RecvObjectList list ->
            ( { model | objList = list }, Cmd.none )

        DeleteObject key ->
            ( model
            , Cmd.batch
                [ Ports.deleteSpatialObject key
                , Notice.waiting Notice ("Deleting '" ++ key ++ "' from database")
                ]
            )

        ToggleLoaded key ->
            ( model, Ports.toggleLoaded key )

        RecvHoverInfo info ->
            ( { model | hoverInfo = info }, Cmd.none )


liftUpdate : (b -> Msg) -> (a -> Model) -> ( a, Cmd b ) -> ( Model, Cmd Msg )
liftUpdate toMsg toModel =
    Tuple.mapBoth toModel (Cmd.map toMsg)



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ Notice.getNotice (Notice.recv Notice)
        , Ports.objectList RecvObjectList
        , Ports.hoverinfo RecvHoverInfo
        ]



-- VIEW


view : Model -> Html
view model =
    div []
        [ div []
            [ text "Hello from Elm land" ]
        , div []
            [ node "dirtvis-viewer" [ style "display" "block", style "width" "500px", style "height" "500px" ] []
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
        (\{ key, status } ->
            div []
                [ strong [] [ text key ]
                , em [] [ text status ]
                , button [ onClick (DeleteObject key) ] [ text "delete" ]
                , button [ onClick (ToggleLoaded key) ] [ text "load/unload" ]
                ]
        )
        >> div []


hoverInfoView : HoverInfo -> Html
hoverInfoView { pointerx, pointery, renderPt, worldPt, meshName } =
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
        , div [] <|
            case meshName of
                Just n ->
                    [ text <| "closest mesh: " ++ decomposeMeshName n ]

                Nothing ->
                    []
        , hr [] []
        ]


p3toString { x, y, z } =
    "(" ++ String.fromFloat x ++ "," ++ String.fromFloat y ++ "," ++ String.fromFloat z ++ ")"


decomposeMeshName n =
    case String.reverse n |> String.split "-" of
        lod :: tile :: rem ->
            "{ key = "
                ++ String.reverse (String.join "-" rem)
                ++ ", tile = "
                ++ String.reverse tile
                ++ ", lod = "
                ++ String.reverse lod
                ++ " }"

        _ ->
            n
