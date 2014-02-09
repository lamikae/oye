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

express = require("express")
assets = require("connect-assets")
# net = require("net")
fs = require("fs")
path = require("path")
oye_home = process.env.OYE_HOME || process.cwd()
nuveAPI_srcdir = process.env.NUVEAPI_SRCDIR || path.join(oye_home,'vendor','licode','nuve','nuveAPI')
db = require(path.join(nuveAPI_srcdir,'mdb','dataBase.js')).db
oye_db = require(path.join(oye_home,'config','oye_config'))
config = require(path.join(oye_home,'config','licode_config'))

try
  # Init NuveAPI for WebRTC.
  N = require(path.join(process.env.LICODE_LIBDIR, 'nuve'))
  N.API.init(
    config.nuve.superserviceID,
    config.nuve.superserviceKey,
    config.nuve.apiURL
  )
catch err
  console.log "ERROR: Nuve could not be loaded", err


exports.listen = (port) ->

  app = exports.app = express()

  app.configure ->
    app.use(express.bodyParser())
    app.use(express.cookieParser('oye'))
    app.use(express.session())
    app.use(express.static(path.join(__dirname,'public')))
    app.use(assets({src: "client"}))
    app.use(express.logger())
    app.set("views", path.join('server','views'))
    app.set("view options", { layout: false })
    app.set("view engine", "jade")

  app.configure "development", ->
    app.use express.errorHandler { dumpExceptions: true, showStack: true }

  app.configure "production", ->
    app.use express.errorHandler()

  app.use  (req, res, next) ->
    res.header('Access-Control-Allow-Origin', '*');
    res.header('Access-Control-Allow-Methods', 'POST, GET');
    res.header('Access-Control-Allow-Headers', 'origin, content-type');
    if req.method == 'OPTIONS'
      res.send(200)
    else
      next()

  app.get "/", (req, resp) ->
    resp.redirect("/login")

  app.get "/login", (req, resp) ->
    resp.render("login", {title: "Please enter access code"})

  app.post "/login", (req, resp) ->
    access_code = req.body.access_code
    validateAccessCode access_code, (user, rooms) ->
      req.session.user = user
      req.session.auth = {username: user.name, roles: user.roles, rooms: rooms, access_code: access_code}
      if rooms.length > 0
        room_id = rooms[0]
        db.rooms.findOne {_id: room_id}, (err, room) =>
          resp.redirect("/room/#{room_id}")
          # success
          return
    ip = req.headers['x-forwarded-for']
    console.log "INFO: Failed /login from #{ip}", req.body
    resp.render("login", {flashmsg: "Oooops, wrong access code!", title: "Please enter access code"})


  # Create Nuve token.
  # Parameters: username, role, room_id
  app.all("/createToken", requireAuthentication)
  app.post "/createToken", (req, resp) ->
    username = req.body.username
    role = req.body.role
    try
      room_id = req.body.room_id
      # console.log "DEBUG: creating token to room ", room_id
      N.API.createToken room_id, username, role, (nuveToken) =>
        console.log "INFO: Created token for #{username} as #{role} to #{room_id}: ", room_id
        resp.send(nuveToken)
    catch err
      console.log "WARNING: Failed to create Nuve token", err


  app.all("/room/*", requireAuthentication)
  app.get "/room/:room_id", (req, resp) ->
    db.rooms.findOne {_id: req.params.room_id}, (err, room) =>
      if err or !room
        console.log("Error:", err)
        resp.send("No such room", 404)
        return
      auth = req.session.auth
      for r_id in auth.rooms
        if r_id == room._id
          console.log "INFO: #{req.session.user.name} logged in to room #{room._id}"
          req.session.room_id = room._id
          template = room.jade
          if template == "p2p"
            title = "video call"
          else
            title = (room.name || "room")
          resp.render(template, {auth: JSON.stringify(auth), title: title, room_id: room._id})
          return
      resp.send("Unauthorized", 401)


  # Back to first room token allows
  app.all("/square1", requireAuthentication)
  app.get "/square1", (req, resp) ->
    unless req.session.auth or req.session.auth.rooms
      resp.redirect("/login")
      return
    for room_id in req.session.auth.rooms
      db.rooms.findOne {_id: room_id}, (err, room) =>
        resp.redirect("/room/#{room._id}")
        return


  # Feedback
  app.get "/feedback", (req, resp) ->
    if req.session.auth and req.session.auth.rooms
      link = "/room/"+req.session.auth.rooms[0]
    else
      link = "#"
    resp.render("feedback", {title: "Feedback form", chatroom_link: link})

  app.post "/feedback", (req, resp) ->
    entry = new Date() + ' -- ' + req.headers['x-forwarded-for'] + ' -- ' + req.headers['user-agent']
    entry += "\n" + req.body.text
    entry += "\n\n-----------------------------------------------\n\n"
    fs.open 'feedback.txt', 'a', 0o0600, (e, id) ->
      fs.write id, entry, null, 'utf8', ->
        fs.close(id)
    resp.send("OK")


  # Open HTTPS server
  if process.env.HTTPS == "1"
    https = require("https")
    tls_options = {
      key: fs.readFileSync(path.join(oye_home,"raspbian","cert","key.pem")).toString(),
      cert: fs.readFileSync(path.join(oye_home,"raspbian","cert","cert.pem")).toString()
    }
    server = https.createServer(tls_options, app)
    server.listen port, -> startupNotice("https", server, app.settings.env)

  # Open HTTP server
  else
    server = app.listen port, ->
      startupNotice("http", server, app.settings.env)
      if port[0] == '/'
        # assume port is an unix socket, assign loose file privileges
        fs.chmod(port, 0x777)


  # Start socket.io for text chat
  msgio = exports.messageCourier.listen(server, {log: true, secure: false})


startupNotice = (protocol, server, env) ->
  # addr is not the public-facing ip, and neither the internal ip, is 0.0.0.0
  addr = server.address()
  # url = "#{protocol}://#{addr.address}:#{addr.port}"
  console.log("Express %s %s server listening at port %d", env, protocol, addr.port)


validateAccessCode = (access_code, callback) ->
  try
    access_codes = oye_db.access_codes.filter((t) -> (t.code == access_code))
    if access_codes.length > 0
      access_code = access_codes[0]
      # console.log "access_code: ", access_code
      users = oye_db.users.filter((u) -> (u.name == access_code.username))
      if users.length > 0
        callback(users[0], (access_code.rooms || []))
  catch err
    console.log err


requireAuthentication = (req, resp, next) ->
  if req.session.auth
    next()
  else
    console.log "Request unauthorized"
    resp.redirect("/login")


#
## Socket.io message courier between user and room
#
exports.messageCourier = {}
exports.messageCourier.listen = (server, options) =>

  io = require('socket.io').listen(server, options)
  io.set('log level', 1)
  io.set('transports', ['websocket'])
  io.set('match origin protocol', true)
  io.on 'connection', (socket) =>

    socket.on 'authenticate', (auth) ->
      # Set custom property on socket
      socket.authorized = false
      # Disconnect socket if validation fails
      bye = setTimeout socket.disconnect, 10000
      validateAccessCode auth.access_code, (user) ->
        socket.authorized = true
        clearTimeout bye


    socket.on 'join', (room_id, username) =>
      # Unauthorized sockets may join, as join request can arrive before auth data.
      try
        db.rooms.findOne {_id: room_id}, (err, room) =>
          if err or !room
            console.log "Error: ", err
            resp.send("No such room", 404)
            return
          # update room socket list
          room.sockets ||= []
          # broadcast message to all in channel
          for sock in room.sockets
            sock.emit('notice', "#{username} joined")
          # add socket to room
          room.sockets.push(socket)
          # ack join to socket
          socket.emit('update', room._id, 'join')
          console.log("INFO: #{username} joined chat in room #{room._id}")
      catch err
        console.log "WARNING: error joining socket to room:", err


    socket.on 'mesg-send', (room_id, message, username) =>
      # Socket must be authorized to send or receive messages
      return unless socket.authorized
      try
        db.rooms.findOne {_id: room_id}, (err, room) =>
          if err
            console.log "Error: ", err
            resp.send("ERROR")
            return
          # check that this socket is in room
          if room.sockets.filter((s) -> (s == socket)).length == 1
            # console.log "DEBUG: message from #{username} to", room._id
            # broadcast message to all in channel
            for sock in room.sockets
              sock.emit('message-receive', message, username)
            return
          else
            console.log "INFO: socket not in room #{room_id}"
      catch err
        console.log "WARNING: error processing incoming message:", err

