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

# Simple messaging over socket.io
class oye.MessageCourier

  auth = null
  socket = null
  roomId = null
  me = null
  timezoneOffset = 0

  constructor: (auth, room_id) ->
    # Get current timezone offset from UTC (minutes)
    d = new Date()
    timezoneOffset = d.getTimezoneOffset()

    # If user is a guest, he is asked to choose a username.
    if auth.roles.indexOf("guest") == -1
      # Connect to websocket server
      connect(auth, room_id)
    else
      # We entirely trust the user and pass no checks on the
      # username validity and availability.
      # The new username is used to login to the room.
      enterUsername = (username) ->
        auth.username = username
        connect(auth, room_id)
      $("#username-chosen").on "keypress", (e) ->
        if e.keyCode == 13
          enterUsername(e.currentTarget.value)
      $("#username-button").on "click", (e) ->
        enterUsername($("#username-chosen")[0].value)
      $("#choose-username").show()


    # Pressing enter key will send the text when element is text input.
    # If the element is a textarea, enter will add a newline while
    # shift+enter will send the text.
    $("#mesg-send").on "keypress", (e) ->
      if e.keyCode == 13
        eName = e.currentTarget.nodeName
        if eName == "INPUT" or (e.shiftKey && eName == "TEXTAREA")
          e.preventDefault()
          text = e.currentTarget.value
          return if text == ""
          if sendMessage(text)
            e.currentTarget.value = ""

    $("#mesg-button").on "click", (e) ->
      el = $("#mesg-send")[0]
      text = el.value
      if sendMessage(text)
        el.value = ""
        el.focus()

    # Sort order
    $("#message-sort-order").
      data("order", "ASC").
      on "click", (event) ->
        event.preventDefault()
        el = event.currentTarget
        if $(el).data("order") != "DESC"
          $(el).
            data("order", "DESC")
            reverseMessages("DESC")
        else
          $(el).
            data("order", "ASC")
            reverseMessages("ASC")


  connect = (auth, room_id) =>
    secure = (document.location.protocol == 'https:')
    if secure
      url = ":443/"
      socket = io.connect(url, {
        resource: "messaging.io",
        secure: secure})
    else
      url = ":3004/"
      socket = io.connect(url, {
        resource: "socket.io",
        secure: secure})
    socket.emit "authenticate", auth
    me = auth.username
    socket.emit "join", room_id, me

    socket.on "update", (room_id_, action) =>
      if action == "join"
        # confirm the update room_id_ matches and store value to roomId
        if room_id_ == room_id
          roomId = room_id_
          # console.log("Connected to chatroom", roomId)
          $("#choose-username").hide()
          $("#send-message").show()

    socket.on "notice", (timestamp, username, message) ->
      showMessage(timestamp, username, message)

    socket.on "message-receive", (timestamp, username, message) ->
      showMessage(timestamp, username, message)


  showMessage = (timestamp, username, message) ->
    div = $("#mesg-recv")
    msghtml = formatMessage(timestamp, username, message)
    if $("#message-sort-order").data("order") == "DESC"
      div.prepend(msghtml)
      div.scrollTop(0)
    else
      div.append(msghtml)
      div.scrollTop(div[0].scrollHeight)
    # adjust messageview size
    # TODO: this should be more dynamic
    div.css("max-height", $(window).height()*2/3)


  sendMessage = (text) =>
    unless socket
      console.log("No socket! Retry connection...")
      connect(auth, roomId)
      return false
    try
      # console.log "Send message to room", roomId
      if roomId
        socket.emit("mesg-send", roomId, text, me)
    catch err
      console.log err


  formatMessage = (timestamp, username, message) =>
    div = document.createElement "div"
    if timestamp
      div.innerHTML += "<span class='timestamp'>[#{formatTime(timestamp)}]</span>&nbsp;"
    if username
      div.innerHTML += "<span class='username'>&lt; #{username}&gt;</span>&nbsp;"
    if message
      msg = message.replace(/\n/g, '<br>&nbsp;&nbsp;')
      div.innerHTML += "<span class='message'>#{msg}</span>"
    return div


  reverseMessages = (order) ->
    fragment = document.createDocumentFragment()
    parent = $("#mesg-recv")
    parent.children("div").each (idx, el) ->
      $(fragment).prepend(el)
    parent.html("")
    parent.append(fragment.cloneNode(true))
    if order == "DESC"
      parent.scrollTop(0)
    else
      parent.scrollTop(parent[0].scrollHeight)


  # Time in hh:mm format from timestamp with current timezone offset.
  formatTime = (timestamp) ->
    timestamp -= timezoneOffset
    minutes = timestamp % 60
    hours = Math.floor((timestamp/60) % 60)
    return pad(hours) + ":" + pad(minutes)


  pad = (number) -> `(number < 10) ? "0"+number : number`
