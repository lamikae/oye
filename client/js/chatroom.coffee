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
class oye.Chatroom

  pom = null
  vgaViewTimeout = null

  constructor: (auth, room_id) ->
    pom = new oye.Sala(auth, room_id)

    # Start stream request so we can see others
    # without sending my stream before user permits it.
    pom.startVideoStreamRequest(
      {audio: false, video: false, data: true, screen: ""},
      streamSubscribeCallback, streamRemoveCallback)

    # Show larger video when user hovers mouse pointer over video preview
    $("div.video").on "mouseenter", (event) ->
      el = event.currentTarget
      if ! $(el).hasClass("unchecked")
        # Active video - display a larger copy in #vga.
        # The timeout lets user have some time to grace around before reacting.
        clearTimeout vgaViewTimeout if vgaViewTimeout
        vgaViewTimeout = setTimeout ->
          v_el = $(el).find("video").clone()[0]
          return unless v_el
          parent = $(".peer#vga")
          parent.find(".video")[0].style.width = "640px"
          parent.find(".video")[0].style.height = "480px"
          v_el.style.width = "inherit"
          v_el.style.height = "inherit"
          v_el.style.position = "relative"
          parent.find(".video-placeholder").hide()
          parent.find("video").remove()
          # append video and disable mouseenter event!
          parent.find(".video").append(v_el).off("mouseenter")
          parent.find(".fullscreen-btn").show()
        , 420
      else
        # Remove video locking by hovering empty slot
        parent = $(".peer#vga")
        parent.find(".video-placeholder").show()
        parent.find(".fullscreen-btn").hide()
        parent.find("video").remove()

    $("div.video").on "mouseleave", (event) -> # noop

    $("#share-options label").on "click", (event) =>
      el = $("input[name=allowed]")[0]
      el.checked = !el.checked
      $("#share-options").trigger("change")

    # Share option is off when page is loaded
    $("input[name=allowed]")[0].checked = false
    # Share video when the option is changed
    $("#share-options").on "change", (event) =>
      el = $("input[name=allowed]")[0]
      if el.checked == true
        # allowed access
        pom.startVideoStreamRequest(
          {audio: false, video: true, data: true, screen: ""},
          streamSubscribeCallback, streamRemoveCallback)
      else
        # disallow video and audio
        # FIXME: this does not work yet.
        # As a workaround, refresh the page and lose all chat log.
        el.checked = true
        alert("I'm afraid I can't do that, #{auth.username}.\nIf you want to stop publishing your stream, you need to reload this page.\nApologies for any inconvenience this may cause you.")
        # pom.unpublishVideoStream()


  streamSubscribeCallback = (stream, isRemote) ->
    if stream.hasVideo()
      div = $(".video.unchecked")[0]
      $(div).removeClass("unchecked")
      elementID = "stream-" + stream.getID();
      div.setAttribute("id", elementID);
      stream.show(elementID);
      # Some ui trickery, sorry for the spaghetti
      $(div).parent("div").find(".fullscreen-btn").show()
      u_el = $(div).find(".username").clone()
      $(div).find(".username").remove()
      $(div).find(".video-placeholder").hide()
      v_el = $("##{stream.elementID}")[0]
      v_el.style.width = "128px"
      v_el.style.height = "96px"
      $(div).append(u_el)
      # As chat and its username is decoupled from erizo stream,
      # we cannot tell which username this is.
      # We shall display the stream label here.
      try
        username = stream.getID()
        if !isRemote
          console.log "My video ID is #{username}"
          # TODO: send this data to server and generate an event
          # to update the username on other clients' view.
      catch
        username = "anon"
      $(div).find(".username").text(username)


  streamRemoveCallback = (stream) ->
    if stream.elementID
      console.log "Stream #{stream.getID()} has disconnected"
      element = $("##{stream.elementID}")
      $(element).find(".video-placeholder").show()
      $(element).parent("div").find(".fullscreen-btn").hide()
      $(element).find(".username").html("&nbsp;")
      $(element).addClass("unchecked")
      try
        document.body.removeChild(element)
      catch err
        console.log err


