pragma Singleton

import QtQuick
import Quickshell
import qs.Commons
import qs.Services.Media

Singleton {
  id: root

  property var lyrics: ["♪"]
  property var lyricTimings: []
  property string currentStatus: ""
  property bool isLoading: false

  readonly property bool hasSyncedLyrics: lyricTimings.length > 0 && lyricTimings.length === lyrics.length
  readonly property int currentLineIndex: hasSyncedLyrics ? indexForTime(MediaService.currentPosition) : -1

  property string _requestedTrackKey: ""
  property int _requestId: 0
  property var _activeRequest: null

  readonly property var _metadataSource: MediaService.currentPlayer && MediaService.currentPlayer._stateSource
    ? MediaService.currentPlayer._stateSource : MediaService.currentPlayer
  readonly property string _observedArtist: String(_metadataSource && _metadataSource.trackArtist !== undefined
    ? _metadataSource.trackArtist : (MediaService.trackArtist || "")).trim()
  readonly property string _observedTitle: String(_metadataSource && _metadataSource.trackTitle !== undefined
    ? _metadataSource.trackTitle : (MediaService.trackTitle || "")).replace(/(\r\n|\n|\r)/g, "").trim()
  readonly property string _observedAlbum: String(_metadataSource && _metadataSource.trackAlbum !== undefined
    ? _metadataSource.trackAlbum : (MediaService.trackAlbum || "")).trim()
  readonly property real _observedDuration: {
    const duration = Number(_metadataSource && _metadataSource.length !== undefined
      ? _metadataSource.length : (MediaService.trackLength || 0))
    return isFinite(duration) && duration > 0 && duration < MediaService.infiniteTrackLength ? duration : 0
  }
  readonly property string _observedTrackKey: [_observedArtist, _observedTitle, _observedAlbum, Math.round(_observedDuration)].join("||")

  on_ObservedTrackKeyChanged: scheduleFetch()

  Component.onCompleted: scheduleFetch()

  Timer {
    id: fetchDebounce
    interval: 75
    repeat: false
    onTriggered: root.checkAndFetch()
  }

  function scheduleFetch() {
    fetchDebounce.restart()
  }

  function checkAndFetch() {
    const artist = _observedArtist
    const title = _observedTitle
    const album = _observedAlbum
    const duration = _observedDuration
    const trackKey = _observedTrackKey

    if (!title) {
      _cancelActiveRequest()
      _requestedTrackKey = ""
      isLoading = false
      currentStatus = ""
      lyricTimings = []
      lyrics = [I18n.tr("lyrics.no-track")]
      return
    }

    if (trackKey === _requestedTrackKey)
      return

    _requestedTrackKey = trackKey
    _requestId++
    _cancelActiveRequest()
    isLoading = true
    currentStatus = I18n.tr("lyrics.searching")
    lyricTimings = []
    lyrics = [I18n.tr("lyrics.searching")]

    _fetchExact(artist, title, album, duration, trackKey, _requestId)
  }

  function _cancelActiveRequest() {
    if (_activeRequest) {
      try {
        _activeRequest.abort()
      } catch (error) {
      }
      _activeRequest = null
    }
  }

  function _isCurrentRequest(trackKey, requestId) {
    return requestId === _requestId && trackKey === _observedTrackKey
  }

  function _fetchExact(artist, title, album, duration, trackKey, requestId) {
    let url = "https://lrclib.net/api/get?artist_name=" + encodeURIComponent(artist)
      + "&track_name=" + encodeURIComponent(title)
    if (album)
      url += "&album_name=" + encodeURIComponent(album)
    if (duration > 0)
      url += "&duration=" + Math.round(duration)

    _getJson(url, trackKey, requestId, function(response) {
      if (root._applyResponse(response, trackKey, requestId))
        return
      root._search(artist, title, album, duration, false, trackKey, requestId)
    }, function() {
      root._search(artist, title, album, duration, false, trackKey, requestId)
    })
  }

  function _search(artist, title, album, duration, normalized, trackKey, requestId) {
    const searchArtist = normalized ? _normalizedArtist(artist) : artist
    const searchTitle = normalized ? _normalizedTitle(title) : title
    let url = "https://lrclib.net/api/search?artist_name=" + encodeURIComponent(searchArtist)
      + "&track_name=" + encodeURIComponent(searchTitle)

    _getJson(url, trackKey, requestId, function(response) {
      const candidate = root._bestCandidate(response, artist, title, album, duration)
      if (candidate && root._applyResponse(candidate, trackKey, requestId))
        return
      if (!normalized && (searchArtist !== root._normalizedArtist(artist) || searchTitle !== root._normalizedTitle(title))) {
        root._search(artist, title, album, duration, true, trackKey, requestId)
        return
      }
      root._finishWithoutLyrics(trackKey, requestId)
    }, function() {
      if (!normalized) {
        root._search(artist, title, album, duration, true, trackKey, requestId)
        return
      }
      root._finishWithError(trackKey, requestId)
    })
  }

  function _getJson(url, trackKey, requestId, onSuccess, onFailure) {
    if (!_isCurrentRequest(trackKey, requestId))
      return

    const xhr = new XMLHttpRequest()
    _activeRequest = xhr
    xhr.open("GET", url, true)
    xhr.setRequestHeader("Accept", "application/json")
    xhr.setRequestHeader("Lrclib-Client", "Hydra Shell (https://github.com/raellv7a-pixel/hydra-shell)")
    xhr.onreadystatechange = function() {
      if (xhr.readyState !== XMLHttpRequest.DONE || !root._isCurrentRequest(trackKey, requestId))
        return

      if (root._activeRequest === xhr)
        root._activeRequest = null

      if (xhr.status < 200 || xhr.status >= 300) {
        onFailure()
        return
      }

      try {
        onSuccess(JSON.parse(xhr.responseText))
      } catch (error) {
        onFailure()
      }
    }
    xhr.send()
  }

  function _applyResponse(response, trackKey, requestId) {
    if (!_isCurrentRequest(trackKey, requestId) || !response)
      return false

    const synced = String(response.syncedLyrics || "")
    const plain = String(response.plainLyrics || "")
    if (synced) {
      const parsed = _parseSyncedLyrics(synced)
      if (parsed.lyrics.length > 0) {
        lyricTimings = []
        lyrics = parsed.lyrics
        lyricTimings = parsed.timings
      } else if (plain) {
        lyricTimings = []
        lyrics = plain.split("\n")
      } else {
        return false
      }
    } else if (plain) {
      lyricTimings = []
      lyrics = plain.split("\n")
    } else {
      return false
    }

    isLoading = false
    currentStatus = ""
    return true
  }

  function _bestCandidate(response, artist, title, album, duration) {
    if (!Array.isArray(response) || response.length === 0)
      return null

    const wantedArtist = _comparable(artist)
    const wantedTitle = _comparable(title)
    const wantedAlbum = _comparable(album)
    let best = null
    let bestScore = -1

    for (let i = 0; i < response.length; i++) {
      const candidate = response[i]
      if (!candidate || (!candidate.syncedLyrics && !candidate.plainLyrics))
        continue

      const candidateArtist = _comparable(candidate.artistName)
      const candidateTitle = _comparable(candidate.trackName)
      const candidateAlbum = _comparable(candidate.albumName)
      let score = 0
      if (candidateTitle === wantedTitle)
        score += 8
      else if (candidateTitle.includes(wantedTitle) || wantedTitle.includes(candidateTitle))
        score += 4
      if (candidateArtist === wantedArtist)
        score += 6
      else if (candidateArtist.includes(wantedArtist) || wantedArtist.includes(candidateArtist))
        score += 3
      if (wantedAlbum && candidateAlbum === wantedAlbum)
        score += 2
      if (duration > 0 && Number(candidate.duration) > 0)
        score += Math.max(0, 2 - Math.abs(Number(candidate.duration) - duration) / 5)

      if (score > bestScore) {
        best = candidate
        bestScore = score
      }
    }
    return best
  }

  function _finishWithoutLyrics(trackKey, requestId) {
    if (!_isCurrentRequest(trackKey, requestId))
      return
    isLoading = false
    currentStatus = I18n.tr("lyrics.not-found-status")
    lyricTimings = []
    lyrics = [I18n.tr("lyrics.not-found")]
  }

  function _finishWithError(trackKey, requestId) {
    if (!_isCurrentRequest(trackKey, requestId))
      return
    isLoading = false
    currentStatus = I18n.tr("lyrics.error-status")
    lyricTimings = []
    lyrics = [I18n.tr("lyrics.error")]
  }

  function _normalizedArtist(artist) {
    return String(artist || "").split(/\s+(?:feat\.?|ft\.?)\s+|\s*[,&]\s*/i)[0].trim()
  }

  function _normalizedTitle(title) {
    return String(title || "")
      .replace(/\s*[([]\s*(?:feat\.?|ft\.?)\s+[^\])]+[\])]/i, "")
      .replace(/\s+-\s+(?:remaster(?:ed)?|live|radio edit).*$/i, "")
      .trim()
  }

  function _comparable(value) {
    return String(value || "").toLocaleLowerCase().replace(/[^a-z0-9\u00c0-\u024f]+/g, " ").trim()
  }

  function _parseSyncedLyrics(syncedText) {
    const sourceLines = String(syncedText).split("\n")
    const parsedLines = []

    for (let i = 0; i < sourceLines.length; i++) {
      const sourceLine = sourceLines[i]
      const timestampPattern = /\[(\d+):(\d+(?:\.\d+)?)\]/g
      let match = timestampPattern.exec(sourceLine)
      if (!match)
        continue

      const text = sourceLine
        .replace(/\[\d+:\d+(?:\.\d+)?\]/g, "")
        .replace(/<\d+:\d+(?:\.\d+)?>/g, "")
        .trim()

      while (match) {
        parsedLines.push({
          "time": Number(match[1]) * 60 + Number(match[2]),
          "text": text
        })
        match = timestampPattern.exec(sourceLine)
      }
    }

    parsedLines.sort(function(left, right) { return left.time - right.time })

    const parsedLyrics = []
    const parsedTimings = []
    for (let i = 0; i < parsedLines.length; i++) {
      parsedLyrics.push(parsedLines[i].text)
      parsedTimings.push(parsedLines[i].time)
    }

    return {
      "lyrics": parsedLyrics,
      "timings": parsedTimings
    }
  }

  function indexForTime(position) {
    if (!hasSyncedLyrics || lyricTimings.length === 0)
      return -1

    const target = Math.max(0, Number(position) || 0) + 0.1
    let low = 0
    let high = lyricTimings.length
    while (low < high) {
      const middle = low + Math.floor((high - low) / 2)
      if (lyricTimings[middle] <= target)
        low = middle + 1
      else
        high = middle
    }
    return low - 1
  }
}
