module ObjectTree exposing (..)

import Cmn
import Css exposing (..)
import Dict exposing (Dict)
import FontAwesome.Attributes
import Html.Styled as Html exposing (..)
import Html.Styled.Attributes as Attr exposing (css, value)
import Html.Styled.Events exposing (..)
import Json.Decode
import List.Extra as Listx
import Notice
import Ports
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
    , popup : Maybe (Cmn.Popup Msg)
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
    , popup = Nothing
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
    , click = PickObjectFile
    }


mkdirAction : Action
mkdirAction =
    { msg = "New folder"
    , icon = Style.iconFolderPlus [ FontAwesome.Attributes.lg ]
    , key = 2
    , click = MakeDirectory
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
    , collapsed : Bool
    }


type alias Object =
    { name : String
    , key : String
    , status : String
    , loaded : Bool
    , selected : Bool
    }


root : Tree
root =
    Parent
        { name = ""
        , children = Dict.empty
        , collapsed = False
        }


newFolder : String -> Tree
newFolder name =
    Parent
        { name = name
        , children = Dict.empty
        , collapsed = False
        }


newObject : String -> String -> Maybe String -> Tree
newObject name key status =
    Child
        { name = name
        , key = key
        , status = Maybe.withDefault "" status
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
                , collapsed = False
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
            case p of
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
            case Debug.log "path" p of
                [] ->
                    putChild child tree

                n :: ns ->
                    getChild n tree
                        |> Maybe.map
                            (inner ns
                                >> (\ch -> putChild ch tree)
                            )
                        |> Maybe.withDefault tree
    in
    inner (List.reverse parent)


putNewFolder : Path -> Tree -> Tree
putNewFolder path =
    let
        inner p tree =
            case p of
                [] ->
                    tree

                n :: ns ->
                    case getChild n tree of
                        -- child exists, apply inner to child
                        Just ch ->
                            putChild (inner ns ch) tree

                        -- child not there, repeat inner at THIS level, putting a new child
                        -- folder into `tree`
                        -- a child will now be picked up
                        Nothing ->
                            inner p (putChild (newFolder n) tree)
    in
    inner (List.reverse path)


updateAt : Path -> (Tree -> Tree) -> Tree -> Tree
updateAt path upd tree =
    case get path tree of
        Just t ->
            if List.isEmpty path then
                upd t

            else
                put (List.drop 1 path) (upd t) tree

        Nothing ->
            tree


{-| Merge two trees together. Collisions will prefer the first tree.
| Note that this recurses.
-}
merge : Tree -> Tree -> Tree
merge a b =
    case ( a, b ) of
        ( Child a_, _ ) ->
            Child a_

        ( Parent a_, Child _ ) ->
            Parent a_

        ( Parent a_, Parent b_ ) ->
            Parent
                { a_
                    | children =
                        Dict.merge
                            Dict.insert
                            (\k l r -> Dict.insert k (merge l r))
                            Dict.insert
                            a_.children
                            b_.children
                            Dict.empty
                }


{-| Perform a test on **all** leaf descendants including this one.
-}
all : (Object -> Bool) -> Tree -> Bool
all pred t =
    case t of
        Child x ->
            pred x

        Parent { children } ->
            Dict.isEmpty children
                |> not
                |> (&&)
                    (Dict.values children |> List.all (all pred))


{-| Perform a test on **any** leaf descendants including this one.
-}
any : (Object -> Bool) -> Tree -> Bool
any pred t =
    case t of
        Child x ->
            pred x

        Parent { children } ->
            Dict.values children |> List.any (any pred)


{-| Reduce tree to only include objects which pass a given predicate.
-}
filter : (Object -> Bool) -> Tree -> Tree
filter pred tree =
    let
        keep _ v =
            case v of
                Child x ->
                    pred x

                Parent { children } ->
                    Dict.isEmpty children |> not

        reduce =
            Dict.filter keep
                >> Dict.map (\_ -> filter pred)
                >> Dict.filter keep
    in
    case tree of
        Child x ->
            Child x

        Parent x ->
            Parent { x | children = reduce x.children }


toggleSelected : Bool -> Tree -> Tree
toggleSelected s t =
    case t of
        Parent x ->
            Parent { x | children = Dict.map (\_ -> toggleSelected s) x.children }

        Child x ->
            Child { x | selected = s }


toggleCollapsed : Bool -> Tree -> Tree
toggleCollapsed c t =
    case t of
        Parent x ->
            Parent
                { x
                    | collapsed = c
                    , children =
                        if c then
                            Dict.map (\_ -> toggleCollapsed c) x.children

                        else
                            x.children
                }

        Child x ->
            Child x


type Msg
    = RecvSpatialObjects (List SpatialObject)
    | SetProgress Progress String
    | ClosePopup
    | RenameStart Path String
    | RenameChange String
    | RenameEnd
    | ToggleSelected Path
    | ToggleCollapsed Path
    | DeleteSelected
    | DeleteSelectedDo FlatTree
    | PickObjectFile
    | MergeFlatTree FlatTree
    | MakeDirectory
    | MakeDirectoryChg String
    | MakeDirectoryDo String


{-| Tree path. Note that this expects to be in **reverse** order (leaf->root).
-}
type alias Path =
    List String


strToPath : String -> Path
strToPath =
    String.split "/"
        >> List.filter (String.isEmpty >> not)
        >> List.reverse


type alias FlatTree =
    List FlatTreeItem


type alias FlatTreeItem =
    { path : String
    , key : String
    , status : Maybe String
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
                    , status = Nothing
                    }
                        :: List.concatMap (loop p) (Dict.values children)

                Child { name, key, status } ->
                    [ { path = path ++ name
                      , key = key
                      , status = Just status
                      }
                    ]
    in
    case tree of
        Parent { children } ->
            List.concatMap (loop "") (Dict.values children)

        -- unreachable at root
        Child _ ->
            []


fromFlatTree : FlatTree -> Tree
fromFlatTree =
    let
        traverse : FlatTreeItem -> Tree -> List String -> Tree
        traverse i tree path =
            case path of
                [] ->
                    tree

                -- folder
                name :: "" :: [] ->
                    putChild (newFolder name) tree

                -- object
                name :: [] ->
                    putChild (newObject name i.key i.status) tree

                name :: ps ->
                    mapChild name (\c -> traverse i c ps) tree

        item : FlatTreeItem -> Tree -> Tree
        item i tree =
            String.split "/" i.path
                |> traverse i tree
    in
    List.sortBy .path
        >> List.filter (.path >> (/=) "/")
        >> List.foldl item root


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

        ClosePopup ->
            ( { model | popup = Nothing }, Cmd.none )

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
                    case tryRename path txt model.objs of
                        Ok tree ->
                            ( { model | renaming = Nothing, objs = tree }
                            , Cmd.none
                            )

                        Err e ->
                            ( model, Notice.sendErr e )

        ToggleSelected path ->
            let
                s =
                    get path model.objs
                        |> Maybe.map (all .selected >> not)
                        |> Maybe.withDefault False
            in
            ( { model | objs = updateAt path (toggleSelected s) model.objs }
                |> insertDeleteAction
            , Cmd.none
            )

        ToggleCollapsed path ->
            let
                s =
                    get path model.objs
                        |> Maybe.map
                            (\t ->
                                case t of
                                    Parent { collapsed } ->
                                        not collapsed

                                    Child _ ->
                                        False
                            )
                        |> Maybe.withDefault False
            in
            ( { model | objs = updateAt path (toggleCollapsed s) model.objs }
            , Cmd.none
            )

        DeleteSelected ->
            ( { model | popup = Just <| deletePopup model }
            , Cmd.none
            )

        DeleteSelectedDo ft ->
            ( { model | popup = Nothing }
            , List.map (.key >> Ports.delete_spatial_object) ft
                |> Cmd.batch
            )

        PickObjectFile ->
            ( model, Ports.pick_spatial_file () )

        MergeFlatTree ft ->
            ( { model | objs = merge (fromFlatTree ft) model.objs }
            , Cmd.none
            )

        MakeDirectory ->
            ( { model | popup = Just <| makeDirPopup model "New Folder" }
            , Cmd.none
            )

        MakeDirectoryChg p ->
            ( { model | popup = Just <| makeDirPopup model p }, Cmd.none )

        MakeDirectoryDo p ->
            let
                path =
                    strToPath p
            in
            if List.isEmpty path then
                ( model, Notice.sendErr <| p ++ " is an empty path" )

            else if member path model.objs then
                ( model, Notice.sendErr <| p ++ " is already a folder" )

            else
                ( { model
                    | objs = putNewFolder path model.objs
                    , popup = Nothing
                  }
                , Cmd.none
                )


recvSpatialObjects : List SpatialObject -> Tree -> Tree
recvSpatialObjects objs tree =
    let
        -- create obj dict by key
        os =
            Debug.log "recvSpatialObjects" objs
                |> List.map (\x -> ( x.key, x ))
                |> Dict.fromList

        reduce :
            FlatTreeItem
            -> ( FlatTree, Dict String SpatialObject )
            -> ( FlatTree, Dict String SpatialObject )
        reduce i ( xs, m ) =
            if i.key == "" then
                ( i :: xs, m )

            else
                case Dict.get i.key m of
                    Just { status } ->
                        ( { i | status = Just status } :: xs
                        , Dict.remove i.key m
                        )

                    Nothing ->
                        ( xs, m )

        -- reduce obj dict as we filter
        ( ft, os2 ) =
            toFlatTree tree
                |> List.foldr reduce ( [], os )

        -- extend with remaining os2
        rem =
            Dict.values os2
                |> List.indexedMap
                    (\i { key, status } ->
                        { path = "un-named " ++ String.fromInt (i + 1)
                        , key = key
                        , status = Just status
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
        [ Maybe.map Cmn.popup tree.popup |> Maybe.withDefault (div [] [])
        , actionBar tree.actions
        , treeView tree
        ]


actionBar : Dict Int Action -> Html Msg
actionBar actions =
    Dict.values actions
        |> List.map
            (\{ msg, icon, click } ->
                button
                    [ Attr.title msg
                    , onClick click
                    , css
                        [ padding2 (px 2) (px 3) ]
                    ]
                    [ icon ]
            )
        |> div [ css [ displayFlex ] ]


treeView : ObjectTree -> Html Msg
treeView tree =
    let
        item : List String -> Tree -> List (Html Msg)
        item path tr =
            let
                name =
                    nameOf tr

                isRoot =
                    String.isEmpty name

                p =
                    if isRoot then
                        []

                    else
                        name :: path

                rename =
                    Cmn.maybeFilter (Tuple.first >> (==) p) tree.renaming
                        |> Maybe.map Tuple.second

                selected =
                    all .selected tr
            in
            case tr of
                Parent x ->
                    itemView
                        (if isRoot then
                            { itemview
                                | path = []
                                , name = "Objects"
                                , renameable = False
                                , selected = selected
                                , icon =
                                    button
                                        [ Attr.title "Collapse all"
                                        , onClick <| ToggleCollapsed []
                                        ]
                                        [ Style.iconObjectRoot [] ]
                            }

                         else
                            { itemview
                                | path = p
                                , name = name
                                , renaming = rename
                                , selected = selected
                                , icon =
                                    if x.collapsed then
                                        button
                                            [ Attr.title "Open"
                                            , onClick <| ToggleCollapsed p
                                            ]
                                            [ Style.iconFolderClosed [] ]

                                    else
                                        button
                                            [ Attr.title "Collapse"
                                            , onClick <| ToggleCollapsed p
                                            ]
                                            [ Style.iconFolderOpen [] ]
                            }
                        )
                        :: (if x.collapsed && not isRoot then
                                []

                            else
                                List.concatMap (item p) (Dict.values x.children)
                           )

                Child x ->
                    [ itemView
                        { itemview
                            | path = p
                            , name = name
                            , renaming = rename
                            , selected = selected
                            , deleting = x.status == SpatialObject.deleting
                            , progress =
                                Dict.get x.key tree.progresses
                                    |> Cmn.maybeFilter
                                        (always <|
                                            x.status
                                                == SpatialObject.preprocessing
                                        )
                            , icon = Style.iconSurface []
                        }
                    ]
    in
    div
        [ css
            [ overflowY auto
            ]
        ]
    <|
        item [] (Debug.log "tree" tree.objs)


type alias ItemView =
    { path : List String
    , name : String
    , renaming : Maybe String
    , renameable : Bool
    , deleting : Bool
    , selected : Bool
    , loaded : Bool
    , progress : Maybe Progress
    , icon : Html Msg
    , collapsed : Bool
    }


itemview : ItemView
itemview =
    { path = []
    , name = ""
    , renaming = Nothing
    , renameable = True
    , deleting = False
    , selected = False
    , loaded = False
    , progress = Nothing
    , icon = Style.iconQuestionMark []
    , collapsed = False
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
                (button
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

                      else if iv.deleting then
                        Html.del

                      else
                        span
                     )
                        [ css [ flex (int 1) ] ]
                        [ name ]
                    )
                |> (::) (div [ css [ padding2 zero (px 3) ] ] [ iv.icon ])
                |> (::)
                    (div
                        [ css
                            [ width
                                (px <|
                                    toFloat <|
                                        (*) 2 <|
                                            List.length iv.path
                                )
                            ]
                        ]
                        []
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
            [ cursor default
            ]
        ]
        [ div
            [ css
                [ displayFlex
                , hover [ backgroundColor Style.theme.bg2 ]
                ]
            ]
            row
        , div
            [ css [ height (px 4), padding2 zero (px 10) ] ]
            [ Maybe.map Progress.viewBar iv.progress |> Maybe.withDefault (div [] []) ]
        ]


deletePopup : ObjectTree -> Cmn.Popup Msg
deletePopup model =
    let
        objs =
            filter .selected model.objs |> toFlatTree
    in
    Cmn.Popup
        "Delete objects"
        (div []
            [ span []
                [ text <|
                    "Delete these "
                        ++ String.fromInt (List.length objs)
                        ++ " objects?"
                ]
            , Html.pre [ css [ maxHeight (px 400), overflow auto ] ]
                [ code []
                    [ List.map .path objs
                        |> List.filter (String.isEmpty >> not)
                        |> String.join "\n"
                        |> text
                    ]
                ]
            ]
        )
        "No"
        ClosePopup
        "🗑 Delete"
        (DeleteSelectedDo objs)


makeDirPopup : ObjectTree -> String -> Cmn.Popup Msg
makeDirPopup model path =
    let
        objs =
            toFlatTree model.objs
                |> List.map .path
                |> List.filter (String.endsWith "/")
                |> Listx.unique
                |> List.map
                    (\x ->
                        code
                            [ onClick <| MakeDirectoryChg x
                            , css
                                [ hover
                                    [ backgroundColor Style.theme.bg1
                                    , cursor pointer
                                    ]
                                ]
                            ]
                            [ text x ]
                    )
    in
    Cmn.Popup
        "Create a folder"
        (div []
            [ input
                [ css [ width (px 450) ]
                , value path
                , onInput MakeDirectoryChg
                ]
                []
            , Html.pre [ css [ displayFlex, flexDirection column ] ] objs
            ]
        )
        "Cancel"
        ClosePopup
        "Create"
        (MakeDirectoryDo path)
