module App.UI exposing (..)

import Dict
import Element as El exposing (Element)
import Element.Background as Background
import Element.Border as Border
import Element.Events as Events
import Element.Font as Font
import Element.Input as Input
import Html exposing (Html)
import Html.Attributes as HA
import Maybe.Extra
import OAuth
import OAuth.Implicit as OAuth
import String.Format

import App exposing (State)
import App.Msg as Msg exposing (Msg)
import Google
import Youtube.Playlist as Playlist
import Youtube.Video as Video


render : State -> Html Msg
render state =
    El.layout
        [ El.width El.fill
        , El.height El.fill
        ]
        <| case state.oauthResult of
            OAuth.Empty ->
                El.column
                    [ Background.color state.theme.bg
                    , El.width <| El.maximum 800 El.fill
                    , El.height El.fill
                    , El.centerX
                    , Font.color state.theme.fg
                    , El.spacing 30
                    ]
                    [ renderHeader state
                    , if not <| Dict.isEmpty state.videos then
                        renderPlayer state
                      else
                        El.none
                    , if not <| Dict.isEmpty state.videos then
                        renderVideoList state
                      else
                        El.none
                    , renderMenu state
                    , renderPlaylistList state
                    , El.column
                        [ El.padding 10
                        , El.scrollbarY
                        , El.height <| El.minimum 200 <| El.shrink
                        ]
                        <| List.map El.text state.messages
                    , renderFooter state
                    ]

            OAuth.Success _ ->
                El.paragraph
                    [ El.paddingEach { paddingZero | top = 20 }
                    , El.spacing 10
                    , Font.center
                    ]
                    [ El.text "Successfully signed in. You can now close this window."
                    ]

            OAuth.Error err ->
                El.paragraph
                    [ El.spacing 10
                    ]
                    [ El.text "An error occured during sign in:"
                    , El.text <| OAuth.errorCodeToString err.error
                    , El.text <| Maybe.withDefault "" err.errorDescription
                    ]


renderHeader : State -> Element msg
renderHeader state =
    El.column
        [ El.width El.fill
        ]
        [ El.el
            [ El.paddingEach { paddingZero | top = 30, bottom = 10 }
            , Font.size 32
            , Font.bold
            ]
            <| El.text "YouTube Playlist"
        , renderSpacer state
        ]


renderFooter : State -> Element msg
renderFooter state =
    El.column
        [ El.width El.fill
        ]
        [ renderSpacer state
        , El.newTabLink
            []
            { label = El.text "Privacy policy"
            , url = "/privacy-policy.html"
            }
        , El.newTabLink
            []
            { label = El.text "View source on GitHub"
            , url = "https://github.com/galdiuz/youtube-playlist"
            }
        ]


renderSpacer : State -> Element msg
renderSpacer state =
    El.el
        [ El.width El.fill
        , El.height <| El.px 1
        , Background.color <| El.rgb 0.5 0.5 0.5
        ]
        El.none


renderMenu : State -> Element Msg
renderMenu state =
    El.column
        [ El.spacing 30
        ]
        [ if state.playlistInStorage then
            El.column
                [ El.spacing 10
                ]
                [ El.el
                    [ Font.size 24
                    ]
                    <| El.text "Resume from previous list"
                , Input.button
                    buttonStyle
                    { onPress = Just <| Msg.PlaylistList <| Msg.LoadListFromStorage
                    , label = El.text "Resume"
                    }
                ]
          else
            El.none
        -- , El.column
        --     [ El.spacing 10
        --     ]
        --     [ El.el
        --         [ Font.size 24
        --         ]
        --         <| El.text "Load playlists by URL"
        --     , Input.multiline
        --         []
        --         { label = Input.labelHidden ""
        --         , onChange = \_ -> Msg.NoOp
        --         , placeholder =
        --             Input.placeholder
        --                 []
        --                 (El.text "https://www.youtube.com/playlist?list=aaabbbccc")
        --                 |> Just
        --         , spellcheck = False
        --         , text = ""
        --         }
        --     , Input.button
        --         buttonStyle
        --         { onPress = Nothing
        --         , label = El.text "Load"
        --         }
        --     ]
        -- , El.column
        --     [ El.spacing 10
        --     ]
        --     [ El.el
        --         [ Font.size 24
        --         ]
        --         <| El.text "Load by user ID"
        --     , Input.text
        --         []
        --         { label = Input.labelHidden ""
        --         , onChange = \_ -> Msg.NoOp
        --         , placeholder = Nothing
        --         , text = ""
        --         }
        --     , Input.button
        --         buttonStyle
        --         { onPress = Nothing
        --         , label = El.text "Load"
        --         }
        --     ]
        , El.column
            [ El.spacing 10
            ]
            [ El.el
                [ Font.size 24
                ]
                <| El.text "Load playlists from your YouTube account"
            , case state.token of
                Just _ ->
                    El.column
                        [ El.spacing 10
                        ]
                        [ El.text <| "Signed in."
                        , Input.button
                            buttonStyle
                            { onPress = Just <| Msg.PlaylistList <| Msg.GetUserPlaylists
                            , label = El.text "Load"
                            }
                        ]

                Nothing ->
                    El.column
                        [ El.spacing 10
                        ]
                        [ El.text "Not signed in."
                        , Input.button
                            buttonStyle
                            { onPress = Just <| Msg.OAuth <| Msg.SignIn
                            , label = El.text "Sign in"
                            }
                        ]
            ]
        ]


renderPlayer : State -> Element Msg
renderPlayer state =
    El.column
        [ El.width El.fill
        , El.spacing 10
        ]
        [ El.el
            [ El.htmlAttribute <| HA.id playerId
            , El.width <| El.maximum 640 <| El.fill
            , El.height El.shrink
            , El.centerX
            ]
            El.none

        , case Dict.get state.current state.videos of
            Just listItem ->
                El.column
                    []
                    [ El.text "Currently playing:"
                    , El.paragraph
                        [ Font.size 28
                        ]
                        [ El.text listItem.video.title
                        ]
                    , case ( listItem.video.startAt, listItem.video.endAt ) of
                        ( Just startAt, Just endAt ) ->
                            "({{}} - {{}})"
                                |> String.Format.value (App.secondsToString <| Just startAt)
                                |> String.Format.value (App.secondsToString <| Just endAt)
                                |> El.text

                        ( Just startAt, Nothing ) ->
                            "({{}} - End)"
                                |> String.Format.value (App.secondsToString <| Just startAt)
                                |> El.text

                        ( Nothing, Just endAt ) ->
                            "(0:00 - {{}})"
                                |> String.Format.value (App.secondsToString <| Just endAt)
                                |> El.text

                        ( Nothing, Nothing ) ->
                            El.none
                    ]

            Nothing ->
                El.none

        , case Dict.get (App.nextIndex state) state.videos of
            Just listItem ->
                El.column
                    []
                    [ El.text "Up next:"
                    , El.paragraph
                        [ Font.size 20
                        ]
                        [ El.text listItem.video.title
                        ]
                    ]

            Nothing ->
                El.none
        , El.row
            [ El.spacing 5
            ]
            [ Input.button
                buttonStyle
                { onPress = Just <| Msg.Player <| Msg.PlayPrevious
                , label = El.text "Play previous"
                }
            , Input.button
                buttonStyle
                { onPress = Just <| Msg.Player <| Msg.PlayNext
                , label = El.text "Play next"
                }
            ]
        ]


renderPlaylistList : State -> Element Msg
renderPlaylistList state =
    if Dict.isEmpty state.lists then
        El.none
    else
        El.column
            [ El.paddingXY 0 5
            , El.spacing 10
            , El.width El.fill
            ]
            [ El.row
                [ El.spacing 5
                ]
                [ Input.button
                    buttonStyle
                    { onPress =
                        state.lists
                            |> Dict.values
                            |> List.filterMap
                                (\listItem ->
                                    if listItem.checked then
                                        Just listItem.playlist
                                    else
                                        Nothing
                                )
                            |> Msg.GetPlaylistVideos
                            |> Msg.PlaylistList
                            |> Just
                    , label = El.text "Confirm"
                    }
                , Input.button
                    buttonStyle
                    { onPress = Just <| Msg.PlaylistList <| Msg.SetCheckedAll
                    , label = El.text "Select all"
                    }
                , Input.button
                    buttonStyle
                    { onPress = Just <| Msg.PlaylistList <| Msg.SetCheckedNone
                    , label = El.text "Deselect all"
                    }
                ]
            , El.column
                [ El.spacing 5
                , El.padding 5
                , El.height <| El.maximum 400 <| El.shrink
                , El.width El.fill
                , El.scrollbarY
                ]
                <| List.map
                    (\listItem ->
                        El.row
                            [ El.spacing 10
                            ]
                            [ Input.checkbox
                                []
                                { onChange = Msg.PlaylistList << Msg.SetChecked listItem.playlist.id
                                , icon = Input.defaultCheckbox
                                , checked = listItem.checked
                                , label = Input.labelRight [] <| El.text listItem.playlist.title
                                }
                            , El.newTabLink
                                buttonStyle
                                { url = Playlist.url listItem.playlist
                                , label = El.text "Open playlist"
                                }
                            ]
                    )
                    (Dict.values state.lists
                        |> List.sortBy (.playlist >> .title)
                    )
            ]


renderVideoList : State -> Element Msg
renderVideoList state =
    El.column
        [ El.scrollbarY
        , El.height <| El.minimum 600 <| El.shrink
        , El.htmlAttribute <| HA.id playlistId
        , El.width El.fill
        ]
        [ El.column
            [ El.spacing 15
            , El.padding 5
            ]
            <| List.map
                (\(index, listItem) ->
                    El.row
                        [ El.spacing 5
                        , El.htmlAttribute <| HA.id <| playlistVideoId index
                        ]
                        [ El.el
                            [ El.alignTop ]
                            <| El.text <| String.fromInt (index + 1) ++ "."
                        , El.column
                            [ El.width El.fill
                            , El.spacing 5
                            ]
                            [ El.paragraph
                                []
                                [ El.text listItem.video.title
                                ]
                            , El.row
                                [ El.spacing 10
                                ]
                                [ Input.button
                                    buttonStyle
                                    { onPress = Just <| Msg.VideoList <| Msg.PlayVideo index
                                    , label = El.text "Play"
                                    }
                                , Input.button
                                    buttonStyle
                                    { onPress = Just (Msg.VideoList (Msg.ToggleEditVideo index (not listItem.editOpen)))
                                    , label = El.text "Edit"
                                    }
                                , El.newTabLink
                                    buttonStyle
                                    { url = Video.url listItem.video
                                    , label = El.text "Open Video"
                                    }
                                , El.newTabLink
                                    buttonStyle
                                    { url = Playlist.url listItem.playlist
                                    , label = El.text "Open Playlist"
                                    }
                                ]
                            , if listItem.editOpen then
                                if Google.tokenHasWriteScope state.token then
                                    El.column
                                        [ El.spacing 10
                                        ]
                                        [ renderTimeInput
                                            { error = listItem.startAtError
                                            , label = "Start:"
                                            , onChange = Msg.VideoList << Msg.SetVideoStartAt index
                                            , onLoseFocus = Msg.VideoList <| Msg.ValidateVideoStartAt index
                                            , value = listItem.startAt
                                            }
                                            state
                                        , renderTimeInput
                                            { error = listItem.endAtError
                                            , label = "End:"
                                            , onChange = Msg.VideoList << Msg.SetVideoEndAt index
                                            , onLoseFocus = Msg.VideoList <| Msg.ValidateVideoEndAt index
                                            , value = listItem.endAt
                                            }
                                            state
                                        , Input.multiline
                                            []
                                            { label = Input.labelLeft [] <| El.text "Note:"
                                            , onChange = Msg.VideoList << Msg.SetVideoNote index
                                            , placeholder = Nothing
                                            , spellcheck = False
                                            , text = listItem.note
                                            }
                                        , El.row
                                            [ El.spacing 10
                                            ]
                                            [ Input.button
                                                buttonStyle
                                                { onPress = Just <| Msg.VideoList <| Msg.SaveVideoTimes index
                                                , label = El.text "Save"
                                                }
                                            , Input.button
                                                buttonStyle
                                                { onPress = Just <| Msg.VideoList <| Msg.ToggleEditVideo index False
                                                , label = El.text "Cancel"
                                                }
                                            ]
                                        ]
                                else
                                    El.row
                                        [ El.spacing 10
                                        ]
                                        [ El.text "Not signed in / not authorized"
                                        , Input.button
                                                buttonStyle
                                                { onPress = Just <| Msg.OAuth <| Msg.SignIn
                                                , label = El.text "Sign in"
                                                }
                                        ]
                              else
                                El.none
                            ]
                        ]
                )
                (Dict.toList state.videos)
        ]


renderTimeInput :
    { error : Maybe String
    , label : String
    , onChange : String -> msg
    , onLoseFocus : msg
    , value : String
    }
    -> State
    -> Element msg
renderTimeInput data state =
    Input.text
        [ El.width <| El.px 75
        , El.below
            ( case data.error of
                Just error ->
                    El.el
                        [ Background.color state.theme.bg
                        , Border.color <| El.rgb 1 0 0
                        , Border.width 1
                        , Border.rounded 5
                        , El.padding 5
                        ]
                        <| El.text error

                Nothing ->
                    El.none
            )
        , Events.onLoseFocus data.onLoseFocus
        , Font.color <| El.rgb 0 0 0
        , maybeAttribute data.error <| Border.color <| El.rgb 1 0 0
        ]
        { label = Input.labelLeft [] <| El.text data.label
        , onChange = data.onChange
        , placeholder = Just <| Input.placeholder [] <| El.text "1:23"
        , text = data.value
        }


maybeAttribute : Maybe a -> El.Attribute msg -> El.Attribute msg
maybeAttribute maybe attr =
    if Maybe.Extra.isJust maybe then
        attr
    else
        El.focused []


buttonStyle : List (El.Attribute msg)
buttonStyle =
    [ El.padding 5
    , Border.width 1
    , Border.rounded 5
    ]


paddingZero : { top : Int, bottom : Int, left : Int, right : Int }
paddingZero =
    { top = 0
    , bottom = 0
    , left = 0
    , right = 0
    }


playerId : String
playerId =
    "player"


playlistId : String
playlistId =
    "playlist"


playlistVideoId : Int -> String
playlistVideoId index =
    "playlist-video-" ++ String.fromInt index
