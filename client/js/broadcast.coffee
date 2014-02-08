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

class oye.Broadcast

  pom = null

  constructor: (auth, room_id) ->
    pom = new oye.Sala(auth, room_id)

    if auth.roles.indexOf("presenter") != -1
      # console.log "I am the presenter"
      pom.startVideoStreamRequest(
        {audio: true, video: true, data: false, screen: ""},
        streamSubscribeCallback, streamRemoveCallback)

    else if auth.roles.indexOf("viewer") != -1
      # console.log "I am a viewer"
      pom.startVideoStreamRequest(
        {audio: false, video: false, data: false, screen: ""},
        streamSubscribeCallback, streamRemoveCallback)


  streamSubscribeCallback = (stream, isRemote) =>
    if stream.hasVideo()
      div = $(".broadcast div.video")[0]
      div.setAttribute("style", "width: 640px; height: 480px;");
      elementID = "stream-" + stream.getID();
      div.setAttribute("id", elementID);
      stream.show(elementID);
      $(div).parent("div").find(".fullscreen-btn").show()
      $(div).find(".video-placeholder").hide()


  streamRemoveCallback = (stream) =>
    if stream.elementID
      element = document.getElementById(stream.elementID)
      $(element).find(".video-placeholder").show()
      $(element).parent("div").find(".fullscreen-btn").hide()
      $(element).addClass("unchecked")
      try
        document.body.removeChild(element)
      catch err
        console.log err


