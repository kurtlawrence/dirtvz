port module ObjectTree exposing (..)

import Cmn
import Css exposing (..)
import Dict exposing (Dict)
import FontAwesome.Attributes
import Html.Styled as Html exposing (..)
import Html.Styled.Attributes as Attr exposing (css)
import Html.Styled.Events exposing (..)
import List.Extra as Listx
import Notice
import Ports
import Progress exposing (Progress)
import Simple.Fuzzy as Fuzzy
import SpatialObject exposing (SpatialObject)
import Style



-- MODEL


type alias ObjectTree =
    { filter : String
    , filterLoaded : Bool
    , actions : Dict Int Action
    , objs : Tree
    , progresses : Dict String Progress
    , renaming : Maybe ( Path, String )
    , popup : Maybe (Cmn.Popup Msg)
    }


empty : ObjectTree
empty =
    { filter = ""
    , filterLoaded = False
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


withFlatTree : FlatTree -> ObjectTree -> ObjectTree
withFlatTree ft x =
    { x | objs = fromFlatTree ft }


type alias Action =
    { msg : String
    , icon : Html Msg
    , key : Int
    , click : Msg
    }


addFileAction : Action
addFileAction =
    { msg = "Load local file"
    , icon = Style.iconFileImport Style.FaLg
    , key = 1
    , click = PickObjectFile
    }


mkdirAction : Action
mkdirAction =
    { msg = "New folder"
    , icon = Style.iconFolderPlus Style.FaLg
    , key = 2
    , click = MakeDirectory
    }


moveToAction : Action
moveToAction =
    { msg = "Move to"
    , icon = Style.iconFolderMove Style.FaLg
    , key = 20
    , click = MoveSelected
    }


bulkLoadAction : Action
bulkLoadAction =
    { msg = "Load selected"
    , icon = Style.iconSolidEye Style.FaLg
    , key = 50
    , click = LoadSelected
    }


bulkUnloadAction : Action
bulkUnloadAction =
    { msg = "Unload selected"
    , icon = Style.iconEmptyEye Style.FaLg
    , key = 51
    , click = UnloadSelected
    }


deleteAction : Action
deleteAction =
    { msg = "Delete objects"
    , icon = Style.iconTrash Style.FaLg
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
                    True

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


{-| This will create a path if one doesn't exist.
-}
move : Path -> Path -> Tree -> Tree
move under node tree =
    case cut node tree of
        ( Just n, tr ) ->
            -- create a path if doesnt exist
            put under n <|
                if member under tree then
                    tr

                else
                    putNewFolder under tr

        ( Nothing, tr ) ->
            tr


put : Path -> Tree -> Tree -> Tree
put parent child =
    let
        inner p tree =
            case p of
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
|
-}
all : (Object -> Bool) -> Bool -> Tree -> Bool
all pred emptyFolder t =
    case t of
        Child x ->
            pred x

        Parent { children } ->
            if Dict.isEmpty children then
                emptyFolder

            else
                Dict.values children |> List.all (all pred emptyFolder)


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


{-| Reduce the tree only keep leaves along `path`.
| This differs to `get` in that the tree is still rooted.
-}
filterTo : Path -> Tree -> Tree
filterTo path =
    let
        inner p tree =
            case p of
                [] ->
                    Just tree

                n :: ns ->
                    getChild n tree
                        |> Maybe.andThen (inner ns)
                        |> Maybe.map (\ch -> newFolder (nameOf tree) |> putChild ch)
    in
    inner (List.reverse path) >> Maybe.withDefault root


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


toggleLoaded : Bool -> Tree -> Tree
toggleLoaded s t =
    case t of
        Parent x ->
            Parent { x | children = Dict.map (\_ -> toggleLoaded s) x.children }

        Child x ->
            Child { x | loaded = s }


type Msg
    = RecvSpatialObjects (List SpatialObject)
    | SetProgress Progress String
    | ClosePopup
    | RenameStart Path String
    | RenameChange String
    | RenameEnd
    | ToggleSelected Path
    | ToggleCollapsed Path
    | ToggleLoaded Path
    | LoadSelected
    | UnloadSelected
    | DeleteSelected
    | DeleteSelectedDo FlatTree
    | DeleteFolder Path
    | PickObjectFile
    | MergeFlatTree FlatTree
    | MakeDirectory
    | MakeDirectoryChg String
    | MakeDirectoryDo String
    | Persist
    | MoveSelected
    | MoveToDirChg String
    | MoveToDo String
    | FilterChg String
    | ToggleLoadedFilter


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


insertMoveToAction : ObjectTree -> ObjectTree
insertMoveToAction model =
    if any .selected model.objs then
        { model | actions = Dict.insert moveToAction.key moveToAction model.actions }

    else
        { model | actions = Dict.remove moveToAction.key model.actions }


insertBulkLoadUnloadAction : ObjectTree -> ObjectTree
insertBulkLoadUnloadAction model =
    let
        selected =
            filter .selected model.objs

        rm a m =
            { m | actions = Dict.remove a.key m.actions }

        add a m =
            { m | actions = Dict.insert a.key a m.actions }
    in
    case ( any (always True) selected, any .loaded selected, all .loaded True selected ) of
        ( False, _, _ ) ->
            rm bulkLoadAction model |> rm bulkUnloadAction

        ( True, False, _ ) ->
            rm bulkUnloadAction model |> add bulkLoadAction

        ( True, _, True ) ->
            add bulkUnloadAction model |> rm bulkLoadAction

        _ ->
            add bulkUnloadAction model |> add bulkLoadAction



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
                            , Cmn.cmd Persist
                            )

                        Err e ->
                            ( model, Notice.sendErr e )

        ToggleSelected path ->
            let
                s =
                    get path model.objs
                        |> Maybe.map (all .selected False >> not)
                        |> Maybe.withDefault False
            in
            ( { model | objs = updateAt path (toggleSelected s) model.objs }
                |> insertDeleteAction
                |> insertMoveToAction
                |> insertBulkLoadUnloadAction
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

        ToggleLoaded path ->
            let
                l =
                    get path model.objs
                        |> Maybe.map (\t -> all .loaded True t && any .loaded t)
                        |> Maybe.map not
                        |> Maybe.withDefault False

                objs =
                    updateAt path (toggleLoaded l) model.objs

                portFn =
                    if l then
                        Ports.object_load

                    else
                        Ports.object_unload
            in
            ( { model | objs = objs } |> insertBulkLoadUnloadAction
            , filterTo path objs
                |> toFlatTree
                |> List.filter (.key >> String.isEmpty >> not)
                |> List.map (.key >> portFn)
                |> Cmd.batch
            )

        LoadSelected ->
            let
                toload =
                    filter .selected model.objs
                        |> filter (.loaded >> not)
                        |> toFlatTree
                        |> List.filter (.key >> String.isEmpty >> not)

                objs =
                    List.map (.path >> strToPath) toload
                        |> List.foldl (\p -> updateAt p (toggleLoaded True)) model.objs
            in
            ( { model | objs = objs } |> insertBulkLoadUnloadAction
            , List.map (.key >> Ports.object_load) toload |> Cmd.batch
            )

        UnloadSelected ->
            let
                tounload =
                    filter .selected model.objs
                        |> filter .loaded
                        |> toFlatTree
                        |> List.filter (.key >> String.isEmpty >> not)

                objs =
                    List.map (.path >> strToPath) tounload
                        |> List.foldl (\p -> updateAt p (toggleLoaded False)) model.objs
            in
            ( { model | objs = objs } |> insertBulkLoadUnloadAction
            , List.map (.key >> Ports.object_unload) tounload |> Cmd.batch
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

        DeleteFolder path ->
            ( { model | objs = cut path model.objs |> Tuple.second }
            , Cmn.cmd Persist
            )

        PickObjectFile ->
            ( model, Ports.pick_spatial_file () )

        MergeFlatTree ft ->
            ( { model | objs = merge (fromFlatTree ft) model.objs }
            , Cmn.cmd Persist
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
                , Cmn.cmd Persist
                )

        Persist ->
            ( model, persist_object_tree <| toFlatTree model.objs )

        MoveSelected ->
            ( { model | popup = Just <| moveToPopup model "" }, Cmd.none )

        MoveToDirChg p ->
            ( { model | popup = Just <| moveToPopup model p }, Cmd.none )

        MoveToDo to ->
            extractMoveNodes model.objs
                |> List.foldl (move (strToPath to)) model.objs
                |> (\o ->
                        ( { model
                            | objs = o
                            , popup = Nothing
                          }
                        , Cmn.cmd Persist
                        )
                   )

        FilterChg f ->
            ( { model | filter = f }, Cmd.none )

        ToggleLoadedFilter ->
            ( { model | filterLoaded = not model.filterLoaded }, Cmd.none )


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


{-| Extract the root node used to move an item.
| We assume that the nodes live in the same directory.
-}
extractMoveNodes : Tree -> List Path
extractMoveNodes tree =
    let
        ft =
            filter .selected tree |> toFlatTree

        pr =
            commonRoot ft
    in
    List.map .path ft
        |> List.filter (String.startsWith pr)
        |> Listx.filterNot ((==) pr)
        |> List.map strToPath


commonRoot : FlatTree -> String
commonRoot =
    let
        inner ps =
            let
                ( head, rem ) =
                    List.filterMap Listx.uncons ps |> List.unzip
            in
            if
                List.isEmpty head
                    || List.head head
                    /= Listx.last head
            then
                ""

            else
                Maybe.withDefault "" (List.head head) ++ "/" ++ inner rem
    in
    List.map .path
        >> List.filter (String.endsWith "/")
        >> List.map (String.dropRight 1)
        >> List.map (String.split "/")
        >> inner
        >> (\s ->
                if String.startsWith "/" s then
                    String.dropLeft 1 s

                else
                    s
           )



-- PORTS


port persist_object_tree : FlatTree -> Cmd a



-- VIEW


view : ObjectTree -> Html Msg
view tree =
    div [ css [ height (pct 100), displayFlex, flexDirection column ] ]
        [ Maybe.map Cmn.popup tree.popup |> Maybe.withDefault (div [] [])
        , filterRow tree
        , actionBar tree.actions
        , treeView tree
        ]


filterRow : ObjectTree -> Html Msg
filterRow model =
    div [ css [ displayFlex ] ]
        [ Cmn.textInput model.filter
            FilterChg
            [ css [ flex (int 1), flexBasis (pct 100), textAlign center ]
            , Attr.placeholder "Filter objects"
            ]
        , button
            [ Attr.title "Loaded/unloaded"
            , onClick ToggleLoadedFilter
            ]
            [ Style.iconLoadedFilterToggle Style.FaDefault ]
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
                    all .selected False tr

                loaded =
                    all .loaded True tr && any .loaded tr
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
                                , loaded = loaded
                                , icon =
                                    button
                                        [ Attr.title "Collapse all"
                                        , Cmn.onClickStopProp <| ToggleCollapsed []
                                        ]
                                        [ Style.iconObjectRoot Style.FaDefault ]
                            }

                         else
                            { itemview
                                | path = p
                                , name = name
                                , renaming = rename
                                , selected = selected
                                , loaded = loaded
                                , deletable = not <| any (always True) tr
                                , icon =
                                    if x.collapsed then
                                        button
                                            [ Attr.title "Open"
                                            , Cmn.onClickStopProp <| ToggleCollapsed p
                                            ]
                                            [ Style.iconFolderClosed Style.FaDefault ]

                                    else
                                        button
                                            [ Attr.title "Collapse"
                                            , Cmn.onClickStopProp <| ToggleCollapsed p
                                            ]
                                            [ Style.iconFolderOpen Style.FaDefault ]
                            }
                        )
                        :: (if x.collapsed && not isRoot then
                                []

                            else
                                Dict.values x.children
                                    |> Listx.stableSortWith viewSortOrder
                                    |> List.concatMap (item p)
                           )

                Child x ->
                    [ itemView
                        { itemview
                            | path = p
                            , name = name
                            , renaming = rename
                            , selected = selected
                            , loaded = loaded
                            , deleting = x.status == SpatialObject.deleting
                            , progress =
                                Dict.get x.key tree.progresses
                                    |> Cmn.maybeFilter
                                        (always <|
                                            x.status
                                                == SpatialObject.preprocessing
                                        )
                            , icon = Style.iconSurface Style.FaDefault
                        }
                    ]
    in
    (if tree.filterLoaded then
        filter .loaded tree.objs

     else
        tree.objs
    )
        |> (\objs ->
                if String.isEmpty tree.filter then
                    objs

                else
                    filter (.name >> Fuzzy.match tree.filter) objs
           )
        |> item []
        |> div
            [ css
                [ overflowY auto, flex3 (int 1) zero zero ]
            ]


viewSortOrder : Tree -> Tree -> Order
viewSortOrder a b =
    case ( a, b ) of
        ( Parent _, Parent _ ) ->
            EQ

        ( Child _, Child _ ) ->
            EQ

        ( Parent _, _ ) ->
            LT

        _ ->
            GT


type alias ItemView =
    { path : List String
    , name : String
    , renaming : Maybe String
    , renameable : Bool
    , deletable : Bool
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
    , deletable = False
    , deleting = False
    , selected = False
    , loaded = False
    , progress = Nothing
    , icon = Style.iconQuestionMark Style.FaDefault
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
                    Cmn.textInput txt
                        RenameChange
                        [ onBlur RenameEnd
                        , Cmn.onEnter RenameEnd
                        ]

        rowBtnStyle =
            css [ padding2 (px 2) (px 2) ]

        row =
            madd iv.deletable
                (button
                    [ Attr.title "Delete"
                    , Attr.class Style.class.displayOnParentHover
                    , Cmn.onClickStopProp (DeleteFolder iv.path)
                    , rowBtnStyle
                    ]
                    [ Style.iconTrash Style.FaDefault ]
                )
                []
                |> madd iv.renameable
                    (button
                        [ Attr.title "Rename"
                        , Attr.class Style.class.displayOnParentHover
                        , Cmn.onClickStopProp (RenameStart iv.path iv.name)
                        , rowBtnStyle
                        ]
                        [ Style.iconPen Style.FaDefault ]
                    )
                |> (::)
                    ((if iv.loaded then
                        Html.strong

                      else if iv.deleting then
                        Html.del

                      else
                        span
                     )
                        [ css
                            [ flex (int 1)
                            , whiteSpace noWrap
                            , overflow hidden
                            , textOverflow ellipsis
                            ]
                        ]
                        [ name ]
                    )
                |> (::) (div [ css [ padding2 zero (px 4) ] ] [ iv.icon ])
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
                        , Cmn.onClickStopProp <| ToggleSelected iv.path
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
            , onClick <| ToggleLoaded iv.path
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
            [ Cmn.textInput path
                MakeDirectoryChg
                [ css [ width (px 450) ] ]
            , Html.pre [ css [ displayFlex, flexDirection column ] ] objs
            ]
        )
        "Cancel"
        ClosePopup
        "Create"
        (MakeDirectoryDo path)


moveToPopup : ObjectTree -> String -> Cmn.Popup Msg
moveToPopup model path =
    let
        count =
            filter .selected model.objs |> toFlatTree |> List.length |> String.fromInt

        objs =
            toFlatTree model.objs
                |> List.map .path
                |> List.filter (String.endsWith "/")
                |> Listx.unique
                |> List.map
                    (\x ->
                        code
                            [ onClick <| MoveToDirChg x
                            , css
                                [ hover
                                    [ backgroundColor Style.theme.bg1
                                    , cursor pointer
                                    ]
                                ]
                            ]
                            [ text x ]
                    )

        create =
            if String.isEmpty path then
                div [] [ Html.em [] [ text "Move to root" ] ]

            else if member (strToPath path) model.objs then
                div [] []

            else
                div [] [ Html.em [] [ text <| "Folder '" ++ path ++ "' will be created" ] ]
    in
    Cmn.Popup
        ("Move " ++ count ++ " items to folder")
        (div []
            [ Cmn.textInput path
                MoveToDirChg
                [ css [ width (px 450) ] ]
            , Html.pre [ css [ displayFlex, flexDirection column ] ] objs
            , create
            ]
        )
        "Cancel"
        ClosePopup
        "Move"
        (MoveToDo path)
