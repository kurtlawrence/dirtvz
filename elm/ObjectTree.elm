module ObjectTree exposing (..)

import Cmn
import Css exposing (..)
import Dict exposing (Dict)
import FontAwesome.Attributes
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
    , actions =
        Dict.fromList
            [ ( addFileAction.key, addFileAction )
            , ( mkdirAction.key, mkdirAction )
            ]
    , objs = root
    , progresses = Dict.empty
    , renaming = Nothing
    }


type alias Action =
    { msg : String
    , icon : Html Msg
    , key : Int
    , click : Msg
    }


addFileAction : Action
addFileAction =
    { msg = "Load local file"
    , icon = Style.iconFileImport [ FontAwesome.Attributes.lg ]
    , key = 1
    , click = DeleteSelected
    }


mkdirAction : Action
mkdirAction =
    { msg = "New folder"
    , icon = Style.iconFolderPlus [ FontAwesome.Attributes.lg ]
    , key = 2
    , click = DeleteSelected
    }


deleteAction : Action
deleteAction =
    { msg = "Delete objects"
    , icon = Style.iconTrash [ FontAwesome.Attributes.lg ]
    , key = 100
    , click = DeleteSelected
    }


type Tree
    = Parent Folder
    | Child Object


type alias Folder =
    { name : String
    , children : Dict String Tree
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
        }


newFolder : String -> Tree
newFolder name =
    Parent
        { name = name
        , children = Dict.empty
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
get path =
    let
        inner p tree =
            case Debug.log "path" p of
                [] ->
                    Just tree

                n :: ns ->
                    getChild n tree
                        |> Maybe.andThen (inner ns)
    in
    inner (List.reverse path)


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


updateAt : Path -> (Tree -> Tree) -> Tree -> Tree
updateAt path upd tree =
    get path tree
        |> Maybe.map (\t -> put (List.drop 1 path) (upd t) tree)
        |> Maybe.withDefault tree


{-| Perform a test on **all** leaf descendants including this one.
-}
all : (Object -> Bool) -> Tree -> Bool
all pred t =
    case t of
        Child x ->
            pred x

        Parent { children } ->
            Dict.values children |> List.all (all pred)


{-| Perform a test on **any** leaf descendants including this one.
-}
any : (Object -> Bool) -> Tree -> Bool
any pred t =
    case t of
        Child x ->
            pred x

        Parent { children } ->
            Dict.values children |> List.any (any pred)


toggleSelected : Tree -> Tree
toggleSelected t =
    case t of
        Parent x ->
            t

        Child x ->
            Child { x | selected = not x.selected }


type Msg
    = RecvSpatialObjects (List SpatialObject)
    | SetProgress Progress String
    | RenameStart Path String
    | RenameChange String
    | RenameEnd
    | ToggleSelected Path
    | DeleteSelected


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


insertDeleteAction : ObjectTree -> ObjectTree
insertDeleteAction model =
    if any .selected model.objs then
        { model | actions = Dict.insert deleteAction.key deleteAction model.actions }

    else
        { model | actions = Dict.remove deleteAction.key model.actions }



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

        ToggleSelected path ->
            ( { model | objs = updateAt path toggleSelected model.objs }
                |> insertDeleteAction
            , Cmd.none
            )

        DeleteSelected ->
            ( model
            , Cmd.none
            )


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
        [ actionBar tree.actions
        , treeView tree.objs tree.renaming
        ]


actionBar : Dict Int Action -> Html Msg
actionBar actions =
    Dict.values actions
        |> List.map
            (\{ msg, icon, click } ->
                Style.button
                    [ Attr.title msg
                    , onClick click
                    , css
                        [ padding2 (px 2) (px 3) ]
                    ]
                    [ icon ]
            )
        |> div [ css [ displayFlex ] ]


treeView : Tree -> Maybe ( Path, String ) -> Html Msg
treeView tree renaming =
    let
        item : List String -> Tree -> List (Html Msg)
        item path tr =
            let
                p =
                    if nameOf tr |> String.isEmpty then
                        []

                    else
                        nameOf tr :: path

                rename =
                    Cmn.maybeFilter (Tuple.first >> (==) p) renaming
                        |> Maybe.map Tuple.second

                selected =
                    all .selected tr
            in
            case tr of
                Parent x ->
                    itemView
                        (if List.isEmpty path then
                            { itemview
                                | path = path
                                , name = "Objects"
                                , renameable = False
                                , selected = selected
                            }

                         else
                            { itemview
                                | path = p
                                , name = x.name
                                , renaming = rename
                                , selected = selected
                            }
                        )
                        :: List.concatMap (item p) (Dict.values x.children)

                Child x ->
                    [ itemView
                        { itemview
                            | path = p
                            , name = x.name
                            , renaming = rename
                            , selected = selected
                        }
                    ]
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
                    [ Style.iconPen [] ]
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
                |> (::)
                    (Style.checkbox
                        [ Attr.checked iv.selected
                        , onClick <| ToggleSelected iv.path
                        ]
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
