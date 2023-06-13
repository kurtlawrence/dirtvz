module ViewerUI exposing (..)

import Browser
import SpatialObject exposing (SpatialObject)
import File exposing (File)
import File.Select
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Notice
import Ports



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
    }


type Msg
    = Notice Notice.Notice
    | PickSpatialFile
    | RecvObjectList (List SpatialObject)


type alias Flags =
    ()


type alias Html =
    Html.Html Msg


init : Flags -> ( Model, Cmd Msg )
init _ =
    ( { notice = Notice.None
    , objList = []
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



liftUpdate : (b -> Msg) -> (a -> Model) -> ( a, Cmd b ) -> ( Model, Cmd Msg )
liftUpdate toMsg toModel =
    Tuple.mapBoth toModel (Cmd.map toMsg)



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
    [ Notice.getNotice (Notice.recv Notice)
    , Ports.objectList RecvObjectList
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
        , div [] [button [onClick PickSpatialFile] [ text "Add spatial object" ] ]
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
    List.map (\{ key, status } -> div [] [ strong [] [ text key ], em [] [ text status ] ])
    >> div []

