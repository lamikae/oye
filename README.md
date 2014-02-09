# Introduction

Thank you for your interest in Oye, the modest WebRTC hub.

These are the install notes to build the server stack on Debian GNU/Linux.

You can run this also on a Raspberry Pi using the Raspbian distribution.


# Install build dependencies


## Clone the main repository

The raspbian stack install script defaults to install libraries to `/opt/share/licode`, this readme uses `/opt/oye`.
All the following commands are intended to be run in this directory.

```
git clone https://github.com/lamikae/oye.git /opt/oye
cd /opt/oye
git submodule init
git submodule update
```


## Compile and install

Let's go through the steps it takes to build the software stack from a clean install.


### Raspbian script

You may not be a fan of monolithic install scripts, but here we have one yet again. If you don't want the script to install node.js from source, you need to install node beforehand. The default install location for the script will be /opt/node; add `/opt/node/bin` to your PATH variable.

```
vendor/licode/scripts/installRaspbianStack.sh
```

It is called "Raspbian" because the script installs MongoDB-less and RabbitMQ-less software stack. It runs on various flavors of Debian GNU/Linux.

Running the script may take a while enough to have coffee or a good night's sleep, depending on your current mood and setup.

The script asks `sudo` multiple times to install built packages.

After the script has run, copy the newly compiled erizo.js to the public directory:

```
cp /opt/share/licode/assets/erizo.js server/public
```

You should also put node to your path

```
echo 'export PATH=/opt/node/bin:$PATH' >> ~/.bashrc
```


### Node dependencies

Install the main application node dependencies.

```
npm install
```

### Create your certificate

You may consider creating your own certificate to `raspbian/cert`.


### Development build

After initial installation, you may use the Makefile to compile licode targets instead of running the full install script again. There is no need for you to do this unless you intend on modifying the source code.

```
make licode
```


### Setup nginx and iptables rules

Nginx is required for full https protection, as browsers tend to ignore encrypted websockets going into different originating ports while using self-signed certificates. This is why nginx is setup to reroute backend websockets to the same port.

Port 8080 is a websocket port for erizo.js <-> ErizoController communication. Port 3004 serves both http and socket.io, while port 3000 is entirely for internal Nuve <-> ErizoController communication. Cloud software can be tricky at times. None of these ports need to be open to the internet once they are proxied by nginx.

The WebRTC streams are packed in sRTP packets that are transmitted over in high UDP ports. Proxy setups have not been tested, and they might turn out to be complicated.

A suggested nginx configuration and a set of iptables firewall rules are provided in the repository. If you installed nginx via the install script, or your nginx resides in `/opt/nginx/`, and `/etc/iptables/` seem like a good place to keep rules, then the defaults are fine.

TL:DR; nginx is required for encrypted websockets.

NOTE: if you're on ssh on other port than default 22, you should check the iptables rules `raspbian/iptables/rules.v4` before reloading the rules to not lock yourself out.

```
sudo make services iptables nginx
sudo service nginx start
```


## Configure

Copy the examples in place and have a look inside, at least for having the demo access codes.

```
cd config
cp licode_config.js~example licode_config.js
cp oye_config.js~example oye_config.js
```

Here are the interesting technical bits you may find interesting.


### STUN server

A STUN server is needed in the configuration. Such server, simply put, responds to your request "what is my ip?" with "to me your ip looks as such", and so ErizoController has acquired the server address to use in peer discovery. If you intend to connect peers over the internet in other than p2p modes, you must set this.

Google provides a free STUN service, although a STUN server would finely fit within the scope of this project.

```
config.erizoController.stunServerUrl = 'stun:stun.l.google.com:19302';
```

In p2p rooms and private networks, where clients can find each other based on their internal ip, no STUN server is needed. This value can then be set to "undefined".

```
config.erizoController.stunServerUrl = undefined;
```

Leaving `config.erizo.stunserver` empty, client browsers are left on their own to discover their address. An empty value should be fine for most clients.

```
config.erizo.stunserver = '';
config.erizo.stunport = 0;
```


### Users

Users are simple creatures; they have a name and some roles. The roles map directly to nuve roles set in licode_config.

```
{name: "gaucho", roles: ["presenter"]},
{name: "amigo",  roles: ["viewer"]},
```

User roles have more meaning than the username. To send and receive video, user must have the "presenter" role, and to only receive, "viewer" is sufficient. An extra role, "guest", exists so that the user can choose his or her username when he enters a room.


### Rooms

Rooms are PeerConnection gathering places. Peers in the same room exchange ICE candidates, and ErizoController handles the offer-answer procedure required for streams to establish. In p2p mode the UDP streams travel literally peer-to-peer, not passing through ErizoController.

Room objects map directly to Nuve rooms. They accept "p2p" and "data" Nuve attributes.


#### Workshop example

You may wish to broadcast a stream from a webcam to an audience, but the actual device has a limited bandwidth, but your server can handle the load.

```
{_id: "workshop", jade: "broadcast", p2p: false},
```

This setting takes the network strain off the device with the input devices; the stream goes to the ErizoController to rebroadcast for connected peers.


#### Private call example

The opposite is a peer-to-peer connection. Your sRTP UDP packet stream will travel directly to its destination and not take a bypass through the server.

```
{_id: "custerdome", jade: "p2p", p2p: true},
```


### Access codes

You have to create access codes for the rooms.
This is the only authentication mechanism in place.
A code is given for a user and is valid for some rooms.
The user is redirected to the room first in the room list. To help user reach the desired page with the code, it can be advised to create multiple codes for single rooms.
All token codes must be unique! This is a humble, modest hub.

```
{code: "defr", username: "gaucho", rooms: ["workshop"]},
{code: "gthy", username: "amigo",  rooms: ["workshop"]},
{code: "r4t5", username: "gaucho", rooms: ["custerdome"]},
{code: "vfbg", username: "amigo",  rooms: ["custerdome"]},
```


# Run the stack

Three processes need to be started. There are currently no service scripts, please supervise them in your favourite multiplexer.

```
make runNuve
```

```
make runErizo
```

```
make runOye
```

Connect to https://host/ and enter an access code.

