module ObjectTree exposing (..)

import Cmn
import Css exposing (..)
import Dict exposing (Dict)
import Html.Styled as Html exposing (..)
import Html.Styled.Attributes as Attr exposing (css, value)
import Html.Styled.Events exposing (..)
import Json.Decode
import Notice
import Progress exposing (Progress)
import SpatialObject exposing (SpatialObject)
import Style



-- MODEL


type alias ObjectTree =
    { filter : String
    , actions : Dict Int Action
    , objs : Tree
    , progresses : Dict String Progress
    , renaming : Maybe ( Path, String )
    }


empty : ObjectTree
empty =
    { filter = ""
    , actions = Dict.empty
    , objs = root
    , progresses = Dict.empty
    , renaming = Nothing
    }


type alias Action =
    { msg : String
    , icon : String
    , click : Msg
    }


type Tree
    = Parent Folder
    | Child Object


type alias Folder =
    { name : String
    , children : Dict String Tree
    , selected : Bool
    }


type alias Object =
    { name : String
    , key : String
    , loaded : Bool
    , selected : Bool
    }


root : Tree
root =
    Parent
        { name = ""
        , children = Dict.empty
        , selected = False
        }


newFolder : String -> Tree
newFolder name =
    Parent
        { name = name
        , children = Dict.empty
        , selected = False
        }


newObject : String -> String -> Tree
newObject name key =
    Child
        { name = name
        , key = key
        , selected = False
        , loaded = False
        }


nameOf : Tree -> String
nameOf tree =
    case tree of
        Parent { name } ->
            name

        Child { name } ->
            name


putChild : Tree -> Tree -> Tree
putChild child tree =
    case tree of
        Parent x ->
            Parent
                { x
                    | children =
                        Dict.insert (nameOf child) child x.children
                }

        Child x ->
            Parent
                { name = x.name
                , children = Dict.fromList [ ( nameOf child, child ) ]
                , selected = False
                }


mapChild : String -> (Tree -> Tree) -> Tree -> Tree
mapChild name updtr tree =
    case tree of
        Parent x ->
            Parent
                { x
                    | children =
                        Dict.update name (Maybe.map updtr) x.children
                }

        Child x ->
            Child x


getChild : String -> Tree -> Maybe Tree
getChild name tree =
    case tree of
        Parent x ->
            Dict.get name x.children

        Child _ ->
            Nothing


member : Path -> Tree -> Bool
member path =
    let
        inner p tree =
            case p of
                [] ->
                    False

                n :: [] ->
                    nameOf tree == n

                n :: ns ->
                    getChild n tree
                        |> Maybe.map (inner ns)
                        |> Maybe.withDefault False
    in
    inner (List.reverse path)


get : Path -> Tree -> Maybe Tree
get path tree =
    Debug.todo ""


cut : Path -> Tree -> ( Maybe Tree, Tree )
cut path =
    let
        rm n tree =
            case tree of
                Parent x ->
                    ( Dict.get n x.children
                    , Parent { x | children = Dict.remove n x.children }
                    )

                Child x ->
                    ( Nothing, Child x )

        inner p tree =
            case p of
                [] ->
                    ( Nothing, tree )

                n :: [] ->
                    rm n tree

                n :: ns ->
                    getChild n tree
                        |> Maybe.map (inner ns >> (\( a, b ) -> ( a, putChild b tree )))
                        |> Maybe.withDefault ( Nothing, tree )
    in
    inner (List.reverse path)


move : Path -> Path -> Tree -> Tree
move node under tree =
    Debug.todo ""


put : Path -> Tree -> Tree -> Tree
put parent child =
    let
        inner p tree =
            case p of
                [] ->
                    putChild child tree

                n :: ns ->
                    getChild n tree
                        |> Maybe.map (inner ns)
                        |> Maybe.withDefault tree
    in
    inner (List.reverse parent)
    


type Msg
    = RecvSpatialObjects (List SpatialObject)
    | SetProgress Progress String
    | RenameStart Path String
    | RenameChange String
    | RenameEnd


{-| Tree path. Note that this expects to be in **reverse** order (leaf->root).
-}
type alias Path =
    List String


type alias FlatTree =
    List FlatTreeItem


type alias FlatTreeItem =
    { path : String
    , key : String
    }


toFlatTree : Tree -> FlatTree
toFlatTree tree =
    let
        loop : String -> Tree -> FlatTree
        loop path tr =
            case tr of
                Parent { name, children } ->
                    let
                        p =
                            path ++ name ++ "/"
                    in
                    { path = p
                    , key = ""
                    }
                        :: List.concatMap (loop p) (Dict.values children)

                Child { name, key } ->
                    [ { path = path ++ name
                      , key = key
                      }
                    ]
    in
    loop "" tree


fromFlatTree : FlatTree -> Tree
fromFlatTree =
    let
        traverse : String -> Tree -> List String -> Tree
        traverse key tree path =
            case path of
                [] ->
                    tree

                -- folder
                name :: "" :: [] ->
                    putChild (newFolder name) tree

                -- object
                name :: [] ->
                    putChild (newObject name key) tree

                name :: ps ->
                    mapChild name (\c -> traverse key c ps) tree

        item : FlatTreeItem -> Tree -> Tree
        item { path, key } tree =
            String.split "/" path
                |> traverse key tree
    in
    List.sortBy .path >> List.foldl item root



-- UPDATE


update : Msg -> ObjectTree -> ( ObjectTree, Cmd Msg )
update msg model =
    case msg of
        RecvSpatialObjects objs ->
            ( { model | objs = recvSpatialObjects objs model.objs }
            , Cmd.none
            )

        SetProgress progress key ->
            ( { model | progresses = Dict.insert key progress model.progresses }
            , Cmd.none
            )

        RenameStart path current ->
            ( { model | renaming = Just ( path, current ) }
            , Cmd.none
            )

        RenameChange txt ->
            ( { model | renaming = Maybe.map (Tuple.mapSecond (always txt)) model.renaming }
            , Cmd.none
            )

        RenameEnd ->
            case model.renaming of
                Nothing ->
                    ( model, Cmd.none )

                Just ( path, txt ) ->
                    case Debug.log "" <| tryRename (Debug.log "path" path) txt model.objs of
                        Ok tree ->
                            ( { model | renaming = Nothing, objs = tree }
                            , Cmd.none
                            )

                        Err e ->
                            ( model, Notice.sendErr e )


recvSpatialObjects : List SpatialObject -> Tree -> Tree
recvSpatialObjects objs tree =
    let
        -- create obj dict by key
        os =
            List.map (\x -> ( x.key, x )) objs
                |> Dict.fromList

        reduce :
            FlatTreeItem
            -> ( FlatTree, Dict String SpatialObject )
            -> ( FlatTree, Dict String SpatialObject )
        reduce i ( xs, m ) =
            if i.key == "" then
                ( i :: xs, m )

            else if Dict.member i.key m then
                ( i :: xs, Dict.remove i.key m )

            else
                ( xs, m )

        -- reduce obj dict as we filter
        ( ft, os2 ) =
            toFlatTree tree
                |> List.foldr reduce ( [], os )

        -- extend with remaining os2
        rem =
            Dict.values os2
                |> List.indexedMap
                    (\i { key } ->
                        { path = "un-named " ++ String.fromInt (i + 1)
                        , key = key
                        }
                    )
    in
    ft ++ rem |> fromFlatTree


tryRename : Path -> String -> Tree -> Result String Tree
tryRename path txt tree =
    if String.isEmpty txt || String.contains "/" txt then
        Err "Name must be non-empty and cannot contain a /"

    else if member (List.drop 1 path |> (::) txt) tree then
        Err <| "Already contains a item '" ++ txt ++ "'"

    else
        case cut path tree of
            ( Just node, tr ) ->
                let
                    n =
                        case node of
                            Parent x ->
                                Parent { x | name = txt }

                            Child x ->
                                Child { x | name = txt }
                in
                Ok <| put (List.drop 1 path) n tr

            _ ->
                Ok tree



-- VIEW


view : ObjectTree -> Html Msg
view tree =
    div []
        [ treeView tree.objs tree.renaming ]


treeView : Tree -> Maybe ( Path, String ) -> Html Msg
treeView tree renaming =
    let
        item : List String -> Tree -> List (Html Msg)
        item path tr =
            let
                p =
                    if nameOf tr |> String.isEmpty then
                        [ ]

                    else
                        nameOf tr :: path

                rename =
                    Cmn.maybeFilter (Tuple.first >> (==) p) renaming
                        |> Maybe.map Tuple.second
            in
            case tr of
                Parent x ->
                    itemView
                        (if List.isEmpty path then
                            { itemview
                                | path = path
                                , name = "Objects"
                                , renameable = False
                            }

                         else
                            { itemview | path = p, name = x.name, renaming = rename }
                        )
                        :: List.concatMap (item p) (Dict.values x.children)

                Child x ->
                    [ itemView { itemview | path = p, name = x.name, renaming = rename } ]
    in
    div
        [ css
            [ overflowY auto
            ]
        ]
    <|
        item [] tree


type alias ItemView =
    { path : List String
    , name : String
    , renaming : Maybe String
    , renameable : Bool
    , selected : Bool
    , loaded : Bool
    }


itemview : ItemView
itemview =
    { path = []
    , name = ""
    , renaming = Nothing
    , renameable = True
    , selected = False
    , loaded = False
    }


itemView : ItemView -> Html Msg
itemView iv =
    let
        madd b d l =
            if b then
                d :: l

            else
                l

        name =
            case iv.renaming of
                Nothing ->
                    text iv.name

                Just txt ->
                    input
                        [ value txt
                        , onInput RenameChange
                        , onBlur RenameEnd
                        , Cmn.onEnter RenameEnd
                        ]
                        []

        row =
            madd iv.renameable
                (Style.button
                    [ Attr.title "Rename"
                    , Attr.class Style.class.displayOnParentHover
                    , onClick (RenameStart iv.path iv.name)
                    ]
                    [ Style.iconPen ]
                )
                []
                |> (::)
                    ((if iv.loaded then
                        Html.em

                      else
                        span
                     )
                        [ css [ flex (int 1) ] ]
                        [ name ]
                    )
    in
    div
        [ css
            [ displayFlex
            , cursor default
            , hover [ backgroundColor Style.theme.bg2 ]
            ]
        ]
        row
