module Youtube.Api exposing
    ( getUserEmail
    , getUserPlaylists
    , getPlaylistVideos
    , getPlaylistsByChannel
    , getPlaylistsByIds
    , updatePlaylistVideo
    )

import Http
import Json.Decode as Decode
import Json.Decode.Field as Field
import Json.Encode as Encode
import Maybe.Extra
import OAuth
import Regex exposing (Regex)
import Url.Builder

import App
import Youtube.Page exposing (Page)
import Youtube.Playlist exposing (Playlist)
import Youtube.Video exposing (Video)


type alias GetParams msg =
    { expect : Http.Expect msg
    , token : Maybe App.Token
    , url : String
    }


type alias PutParams msg =
    { body : Encode.Value
    , expect : Http.Expect msg
    , token : Maybe App.Token
    , url : String
    }


get : GetParams msg -> Cmd msg
get { expect, token, url } =
    Http.request
        { method = "GET"
        , headers =
            case token of
                Just t ->
                    OAuth.useToken t.token []
                Nothing ->
                    []
        , url = url
        , expect = expect
        , body = Http.emptyBody
        , timeout = Nothing
        , tracker = Nothing
        }


put : PutParams msg -> Cmd msg
put { body, expect, token, url } =
    Http.request
        { method = "PUT"
        , headers =
            case token of
                Just t ->
                    OAuth.useToken t.token []
                Nothing ->
                    []
        , url = url
        , expect = expect
        , body = Http.jsonBody body
        , timeout = Nothing
        , tracker = Nothing
        }


getUserEmail :
    Maybe App.Token
    -> (Result Http.Error String -> msg)
    -> Cmd msg
getUserEmail oauthToken toMsg =
    get
        { url = userInfoUrl
        , expect = Http.expectJson toMsg userEmailDecoder
        , token = oauthToken
        }


userEmailDecoder : Decode.Decoder String
userEmailDecoder =
    Decode.field "email" Decode.string


userInfoUrl : String
userInfoUrl =
    "https://openidconnect.googleapis.com/v1/userinfo"


getUserPlaylists :
    Maybe App.Token
    -> Maybe String
    -> (Result Http.Error (Page Playlist) -> msg)
    -> Cmd msg
getUserPlaylists oauthToken pageToken toMsg =
    get
        { url = userPlaylistsUrl pageToken
        , expect = Http.expectJson toMsg (Youtube.Page.decoder playlistDecoder)
        , token = oauthToken
        }


getPlaylistVideos :
    String
    -> Maybe App.Token
    -> Maybe String
    -> (Result Http.Error (Page Video) -> msg)
    -> Cmd msg
getPlaylistVideos playlistId oauthToken pageToken toMsg =
    get
        { url = playlistVideosUrl playlistId pageToken
        , expect = Http.expectJson toMsg (Youtube.Page.decoder playlistItemDecoder)
        , token = oauthToken
        }


playlistVideosUrl : String -> Maybe String -> String
playlistVideosUrl playlistId pageToken =
    Url.Builder.crossOrigin
        "https://www.googleapis.com/youtube/v3/playlistItems"
        []
        [ Url.Builder.string "part" "snippet,contentDetails"
        , Url.Builder.string "playlistId" playlistId
        , Url.Builder.int "maxResults" 50
        , Url.Builder.string "pageToken" <| Maybe.withDefault "" pageToken
        ]


getPlaylistsByChannel :
    String
    -> Maybe App.Token
    -> Maybe String
    -> (Result Http.Error (Page Playlist) -> msg)
    -> Cmd msg
getPlaylistsByChannel channelId oauthToken pageToken toMsg =
    get
        { url = playlistsByChannelUrl channelId pageToken
        , expect = Http.expectJson toMsg (Youtube.Page.decoder playlistDecoder)
        , token = oauthToken
        }


playlistsByChannelUrl : String -> Maybe String -> String
playlistsByChannelUrl channelId pageToken =
    Url.Builder.crossOrigin
        "https://www.googleapis.com/youtube/v3/playlists"
        []
        [ Url.Builder.string "part" "snippet"
        , Url.Builder.int "maxResults" 50
        , Url.Builder.string "channelId" channelId
        , Url.Builder.string "pageToken" <| Maybe.withDefault "" pageToken
        ]


getPlaylistsByIds :
    List String
    -> Maybe App.Token
    -> Maybe String
    -> (Result Http.Error (Page Playlist) -> msg)
    -> Cmd msg
getPlaylistsByIds playlistIds oauthToken pageToken toMsg =
    get
        { url = playlistsByIdUrl playlistIds pageToken
        , expect = Http.expectJson toMsg (Youtube.Page.decoder playlistDecoder)
        , token = oauthToken
        }


playlistsByIdUrl : List String -> Maybe String -> String
playlistsByIdUrl playlistIds pageToken =
    Url.Builder.crossOrigin
        "https://www.googleapis.com/youtube/v3/playlists"
        []
        [ Url.Builder.string "part" "snippet"
        , Url.Builder.int "maxResults" 50
        , Url.Builder.string "id" <| String.join "," playlistIds
        , Url.Builder.string "pageToken" <| Maybe.withDefault "" pageToken
        ]


userPlaylistsUrl : Maybe String -> String
userPlaylistsUrl pageToken =
    Url.Builder.crossOrigin
        "https://www.googleapis.com/youtube/v3/playlists"
        []
        [ Url.Builder.string "part" "snippet"
        , Url.Builder.int "maxResults" 50
        , Url.Builder.string "mine" "true"
        , Url.Builder.string "pageToken" <| Maybe.withDefault "" pageToken
        ]


playlistDecoder : Decode.Decoder Playlist
playlistDecoder =
    Field.require "id" Decode.string <| \id ->
    Field.requireAt [ "snippet", "title" ] Decode.string <| \title ->
    Decode.succeed
        { id = id
        , title = title
        }


playlistItemDecoder : Decode.Decoder Video
playlistItemDecoder =
    Field.requireAt [ "contentDetails", "videoId" ] Decode.string <| \id ->
    Field.requireAt [ "snippet", "title" ] Decode.string <| \title ->
    Field.requireAt [ "snippet", "position" ] Decode.int <| \position ->
    Field.requireAt [ "snippet", "playlistId" ] Decode.string <| \playlistId ->
    Field.requireAt [ "id" ] Decode.string <| \itemId ->
    Field.attemptAt [ "contentDetails", "note" ] Decode.string <| \rawNote ->
    let
        (note, startAt, endAt) =
            decodeNote rawNote
    in
    Decode.succeed
        { id = id
        , title = title
        , startAt = startAt
        , endAt = endAt
        , position = position
        , playlistId = playlistId
        , itemId = itemId
        , note = note
        }


updatePlaylistVideo :
    Video
    -> Maybe App.Token
    -> (Result Http.Error Video -> msg)
    -> Cmd msg
updatePlaylistVideo video oauthToken toMsg =
    put
        { body = updatePlaylistVideoBody video
        , expect = Http.expectJson toMsg playlistItemDecoder
        , token = oauthToken
        , url = updatePlaylistVideoUrl
        }


updatePlaylistVideoUrl : String
updatePlaylistVideoUrl =
    Url.Builder.crossOrigin
        "https://www.googleapis.com/youtube/v3/playlistItems"
        []
        [ Url.Builder.string "part" "snippet,contentDetails"
        ]


updatePlaylistVideoBody : Video -> Encode.Value
updatePlaylistVideoBody video =
    Encode.object
        [ ( "id", Encode.string video.itemId )
        , ( "snippet"
          , Encode.object
            [ ( "playlistId", Encode.string video.playlistId )
            , ( "resourceId"
              , Encode.object
                [ ( "kind", Encode.string "youtube#video" )
                , ( "videoId", Encode.string video.id )
                ]
              )
            , ( "position", Encode.int video.position )
            ]
          )
        , ( "contentDetails"
          , Encode.object
            [ ( "note", encodeNote video )
            ]
          )
        ]


decodeNote : Maybe String -> (Maybe String, Maybe Int, Maybe Int)
decodeNote maybeString =
    case (maybeString, noteRegex) of
        (Just string, Just regex) ->
            string
                |> Regex.find regex
                |> List.head
                |> Maybe.map
                    (\{submatches} ->
                        case submatches of
                            [_, note, _, startAt, _, endAt] ->
                                ( note
                                , Maybe.andThen String.toInt startAt
                                , Maybe.andThen String.toInt endAt
                                )

                            _ ->
                                (Just string, Nothing, Nothing)
                    )
                |> Maybe.withDefault (Just string, Nothing, Nothing)

        _ ->
            (Nothing, Nothing, Nothing)


noteRegex : Maybe Regex
noteRegex =
    Regex.fromString "^((.*)\\n\\n)?\\[\\[(s=(\\d+))?(e=(\\d+))?\\]\\]$"


encodeNote : Video -> Encode.Value
encodeNote video =
    Encode.string
        <| case (video.note, formatTimes video) of
            (Just note, Just times) ->
                note ++ "\n\n" ++ times

            (Just note, Nothing) ->
                note

            (Nothing, Just times) ->
                times

            (Nothing, Nothing) ->
                ""


formatTimes : Video -> Maybe String
formatTimes video =
    case (video.startAt, video.endAt) of
        (Just startAt, Just endAt) ->
            Just <| "[[s=" ++ String.fromInt startAt ++ "e=" ++ String.fromInt endAt ++ "]]"

        (Just startAt, Nothing) ->
            Just <| "[[s=" ++ String.fromInt startAt ++ "]]"

        (Nothing, Just endAt) ->
            Just <| "[[e=" ++ String.fromInt endAt ++ "]]"

        (Nothing, Nothing) ->
            Nothing
