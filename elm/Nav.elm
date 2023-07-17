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
    | Settings



-- VIEW


view : (State -> a) -> State -> Html a
view newState state =
    div
        [ css <|
            [ displayFlex
            , flexDirection column
            , alignItems center
            ]
                ++ Style.panelBorders
        ]
        (List.map (btnView newState state) btns)


type alias Btn a =
    { title : String
    , icon : Html a
    , navTo : State
    }


btns : List (Btn a)
btns =
    [ { title = "Objects"
      , icon = Style.iconObjectRoot Style.FaLg
      , navTo = Objects
      }
    , { title = "Settings"
      , icon = Style.iconGear Style.FaLg
      , navTo = Settings
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
        [ css
            [ opacity (num op)
            , marginBottom (px 10)
            ]
        , Attr.title title
        , onClick (click navTo)
        ]
        [ b.icon ]
