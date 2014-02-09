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

class oye.PeerToPeer

  pom = null

  constructor: (auth, room_id) ->
    pom = new oye.Sala(auth, room_id)
    # assume peer has allowed media access (browser will ask the first time)
    pom.startVideoStreamRequest(
      {audio: true, video: true, data: false, screen: ""},
      streamSubscribeCallback, streamRemoveCallback)


  streamSubscribeCallback = (stream, isRemote) ->
    sid = stream.getID()
    if !isRemote
      div = $(".mio div.video")[0]
      div.setAttribute("style", "width: 128px; height: 96px;");
    else
      # console.log "Subscribing to remote stream #{sid}"
      div = $("#stream-#{sid}")[0]
      div = $(".amigo div.video")[0]
      style = "width: 640px; height: 480px;"
      if $(div).hasClass("fullscreen")
        style = "width: 100%; height: 100%;"
      div.setAttribute("style", style)
      # $(div).find(".video-placeholder")[0].setAttribute("style", style)

    elementID = "stream-" + stream.getID();
    div.setAttribute("id", elementID);
    stream.show(elementID);
    $(div).parent("div").find(".fullscreen-btn").show()
    $(div).find(".video-placeholder").hide()


  streamRemoveCallback = (stream) =>
    if stream.elementID
      element = document.getElementById(stream.elementID)
      $(element).parent("div").find(".fullscreen-btn").hide()
      $(element).find(".video-placeholder").show()
      try
        document.body.removeChild(element)
      catch err
        console.log err

