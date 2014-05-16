# Introduction

Thank you for your interest in Oye.
These notes walk you through installing a modest personal WebRTC stack on Debian GNU/Linux.


# Install build dependencies


## Clone the main repository

```
git clone --recursive https://github.com/lamikae/oye.git /opt/oye
cd /opt/oye
```

Licode submodule must be kept updated if not tracked automatically.
```
git submodule update
```


## Compile and install

Let's go through the steps it takes to build the software stack from a clean install.


### Raspbian stack

The stack command will install a load of dependencies on Debian GNU/Linux derivatives. Some packages are from apt repositories, while some are compiled from sources and bundled into deb packages for the system package manager to index.

Include path to node binary in your global $PATH:

```
echo -e "\nexport PATH=/opt/node/bin:$PATH" >> ~/.bashrc
source ~/.bashrc
```

This will install MongoDB-less and RabbitMQ-less software stack.
It may take a while. The script will ask for `sudo` to install debian packages into the system.

```
make stack
```

NOTE: npm may fail to install all dependencies. Read the error message and try again a few times and the issue might be solved.



### Build licode

Compile licode to ensure you have the latest build.

```
make licode
```


### Setup nginx and iptables rules

Nginx is the HTTP(S) frontend for all backend services.

Port 8080 is a websocket port for erizo.js <-> ErizoController communication. Port 3004 serves both http and socket.io, while port 3000 is entirely for internal Nuve <-> ErizoController communication. None of these ports need to be open to the internet once they are proxied by nginx.

The WebRTC streams travel in sRTP packets at high UDP ports. Proxy setups  might turn out to be complicated.

TL:DR; nginx is required for encrypted websockets. Nginx configuration and a set of iptables firewall rules are provided in the repository.

NOTE: if you're on ssh on other port than default 22, you should check the iptables rules `raspbian/iptables/rules.v4` before reloading the rules **not to lock yourself out**.

```
sudo make services iptables nginx
sudo service nginx start
```


### Create your certificate

You may consider creating your own certificate to `raspbian/cert`.


## Configure

Copy and edit the example configuration files.

```
cd config
cp oye_config.js~example oye_config.js
cp licode_config.js~example licode_config.js
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


#### Broadcast

You may wish to broadcast a stream from a webcam to an audience.
The stream travels through ErizoController rebroadcast for connected peers.

```
{_id: "stadium", jade: "broadcast", p2p: false},
```


#### Peer to peer

In this setup the sRTP UDP packet streams travel directly to their destination.

```
{_id: "custerdome", jade: "p2p", p2p: true},
```


### Access codes

Access codes bind users to rooms. A single code can grant access to multiple rooms, and the user is redirected to the first one. **All token codes must be unique!**

```
{code: "defr", username: "gaucho", rooms: ["stadium"]},
{code: "gthy", username: "amigo",  rooms: ["stadium"]},
{code: "r4t5", username: "gaucho", rooms: ["custerdome"]},
{code: "vfbg", username: "amigo",  rooms: ["custerdome"]},
```


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

