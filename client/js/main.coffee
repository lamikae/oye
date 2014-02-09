# Oye - simple WebRTC hub
# Copyright (C) 2014 lamikae
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

window.oye = {}

# Shared methods for all operating modes using erizo.js API.
class oye.Sala

  room_id: undefined
  auth: {}
  roles: []
  erizoStream: null
  room: null

  constructor: (@auth, @room_id) ->
    L.Logger.setLogLevel(L.Logger.INFO)
    @roles = @auth.roles
    # Setup fullscreen onclick, hide until video ready
    $(".fullscreen-btn").hide().on "click", (event) ->
      video = $(event.currentTarget).parent("div").find(".video")[0]
      return unless video
      requestFullscreenForVideo(video)


  createToken: (callback) =>
    # console.log "createToken", room_id
    req = new XMLHttpRequest()
    url = "/createToken"
    if (@auth.roles.indexOf("presenter")) != -1
      role = "presenter"
    else if (@auth.roles.indexOf("viewer")) != -1
      role = "viewer"
    params = {username: @auth.username, role: role, room_id: @room_id}
    req.onreadystatechange = ->
      if req.readyState == 4
        callback(req.responseText)
    req.open('POST', url, true)
    req.setRequestHeader('Content-Type', 'application/json')
    req.send(JSON.stringify(params))


  requestFullscreenForVideo = (video) =>
    return unless screenfull.enabled
    fullscreenVideoOriginalDimensions = [
      $(video).css("width"),
      $(video).css("height")
    ]
    screenfull.request(video)
    screenfull.onchange = (event) =>
      if screenfull.isFullscreen
        style = "width: 100%; height: 100%;"
        $(video).find(".video-placeholder")[0].setAttribute("style", style+" display: none;")
        video.setAttribute("style", style)
        $(video).find("video")[0].setAttribute("style", style)
        $(video).addClass("fullscreen")
        # hide loader that may appear after switching fullscreen
        loader = $("##{video.id.replace('stream-','back_')}")
        loader.hide() if loader
      else
        style = "width: #{fullscreenVideoOriginalDimensions[0]}; height: #{fullscreenVideoOriginalDimensions[1]};"
        video.setAttribute("style", style)
        $(video).find("video")[0].setAttribute("style", style)
        $(video).find(".video-placeholder")[0].setAttribute("style", style+" display: none;")
        $(video).removeClass("fullscreen")


  startVideoStreamRequest: (options, subscribeCallback, removeCallback) =>
    if @erizoStream
      # Close existing erizoStream
      @erizoStream.close()
    # Open new Erizo Stream
    @erizoStream = Erizo.Stream(options)
    # Create token and join room, send and recv streams
    @createToken (token) =>
      room = Erizo.Room({token: token})

      @erizoStream.addEventListener "access-accepted", =>
        subscribeToStreams = (streams) =>
          for stream in streams
            room.subscribe(stream)

        room.addEventListener "room-connected", (roomEvent) =>
          # console.log "Connected to room", roomEvent
          # send local stream
          room.publish(@erizoStream)
          # receive other stream
          subscribeToStreams(roomEvent.streams)

        room.addEventListener "stream-added", (streamEvent) =>
          streams = []
          streams.push(streamEvent.stream)
          subscribeToStreams(streams)

        room.addEventListener "stream-subscribed", (streamEvent) =>
          stream = streamEvent.stream
          isRemote = (stream.getID() != @erizoStream.getID())
          subscribeCallback(stream, isRemote)
          streams = Object.keys(room.remoteStreams).map(((id) => return room.remoteStreams[id]))

        room.addEventListener "stream-removed", (streamEvent) =>
          removeCallback(streamEvent.stream)

        # Connect to the room once all event listeners are set.
        room.connect()
        @room = room

      console.log "Starting WebRTC handshake"
      @erizoStream.init()


  # FIXME: unpublishing does not work properly yet.
  unpublishVideoStream: () =>
    return unless @erizoStream
    stream_id = @erizoStream.getID()
    console.log("Unpublish video stream")
    # unpublish
    @room.unpublish(@erizoStream)
    # disconnect video ui
    div = $("#stream-#{stream_id}")
    videoElem = $(div).find("video")[0]
    videoElem.remove()
    setTimeout =>
      $(div).find(".video-placeholder").show()
      $(div).find("#player_#{stream_id}").remove()
      $(div).find("#bar_#{stream_id}").remove()
      $(div).addClass("unchecked")
    , 750

