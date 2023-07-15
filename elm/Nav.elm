module Nav exposing (..)

import Css exposing (..)
import FontAwesome.Attributes
import Html.Styled exposing (..)
import Html.Styled.Attributes as Attr exposing (css)
import Html.Styled.Events exposing (..)
import Style


type State
    = None
    | Objects



-- VIEW


view : (State -> a) -> State -> Html a
view newState state =
    div
        [ css Style.panelBorders ]
        (List.map (btnView newState state) btns)


type alias Btn a =
    { title : String
    , icon : Html a
    , navTo : State
    }


btns : List (Btn a)
btns =
    [ { title = "Objects"
      , icon = Style.iconObjectRoot [ FontAwesome.Attributes.lg ]
      , navTo = Objects
      }
    ]


btnView : (State -> a) -> State -> Btn a -> Html a
btnView click on b =
    let
        { title, navTo, op } =
            if b.navTo == on then
                { title = "Hide " ++ b.title
                , navTo = None
                , op = 0.8
                }

            else
                { title = "Open " ++ b.title
                , navTo = b.navTo
                , op = 0.5
                }
    in
    button
        [ css [ opacity (num op) ]
        , Attr.title title
        , onClick (click navTo)
        ]
        [ b.icon ]
