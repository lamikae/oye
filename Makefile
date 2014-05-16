####
###
#   Makefile for oye
##
###
MY_DIR            := `pwd`
ASSETS_DIR        := $(MY_DIR)/server/public
LICODE_SRCDIR     := $(MY_DIR)/vendor/licode
LICODE_LIBDIR     := /opt/share/licode/lib
NODEJS_BINDIR     := /opt/node/bin

licode: nuve erizo
	# LIST
	@du -h \
		$(LICODE_LIBDIR)/nuve.js \
		$(LICODE_LIBDIR)/liberizo.so \
		$(LICODE_LIBDIR)/erizoAPI/* \
		$(ASSETS_DIR)/erizo*.js
nuve: nuve.js
erizo: liberizo.so erizoAPI erizo.js
build: all
all: licode
stack:
	@npm install
	@./vendor/licode/scripts/installRaspbianStack.sh

# # #

liberizo.so: prepare
	# COMPILING liberizo.so
	@if [ ! -e $(LICODE_SRCDIR)/erizo/build ]; then \
		mkdir $(LICODE_SRCDIR)/erizo/build ;\
	fi
	@\
	export LD_LIBRARY_PATH=$(LICODE_LIBDIR):$(LICODE_LIBDIR):$(SSL_LIBDIR) && \
	cd $(LICODE_SRCDIR)/erizo/build && \
		cmake ../src && make
	@cp -a $(LICODE_SRCDIR)/erizo/build/erizo/liberizo.so $(LICODE_LIBDIR)
	@du -h $(LICODE_LIBDIR)/liberizo.so
	# READY.
	@echo


erizoAPI: liberizo.so
	# COMPILING erizoAPI
	@\
	export ERIZO_HOME=$(LICODE_SRCDIR)/erizo && \
	export PATH=$$PATH:$(MY_DIR)/node_modules/.bin && \
	cd $(LICODE_SRCDIR)/erizoAPI && \
		node-gyp configure build
	@mkdir -p $(LICODE_LIBDIR)/erizoAPI
	@cp $(LICODE_SRCDIR)/erizoAPI/build/Release/addon.node $(LICODE_LIBDIR)/erizoAPI/
	@du -h $(LICODE_LIBDIR)/erizoAPI/*
	# READY.
	@echo


erizo.js:
	# COMPILING erizo.js
	cd $(LICODE_SRCDIR)/erizo_controller/erizoClient/tools && \
		./compile.sh && \
		./compilefc.sh
	@cp $(LICODE_SRCDIR)/erizo_controller/erizoClient/dist/erizo.js $(ASSETS_DIR)
	@du -h $(ASSETS_DIR)/erizo*
	# READY.
	@echo


nuve.js:
	# COMPILING nuve.js
	cd $(LICODE_SRCDIR)/nuve/nuveClient/tools && ./compile.sh
	@cp $(LICODE_SRCDIR)/nuve/nuveClient/dist/nuve.js $(LICODE_LIBDIR)
	@du -h $(LICODE_LIBDIR)/nuve.js
	# READY.
	@echo


runNuve:
	@echo " * Start Nuve"
	@# Remove unix sockets from previous run
	@-rm -f /tmp/nuve*.sock
	@# Create missing licode_config.js symlink
	@if [ ! -e $(LICODE_SRCDIR)/licode_config.js ]; then \
		config_file="`pwd`/config/licode_config.js" && \
		cd $(LICODE_SRCDIR) && ln -s "$${config_file}" . ; \
	fi
	export LD_LIBRARY_PATH=$(LICODE_LIBDIR) && \
	export PATH=$(NODEJS_BINDIR):$$PATH && \
	cd $(LICODE_SRCDIR)/nuve/nuveAPI && \
		node nuve.js


runErizo:
	@echo " * Start ErizoController"
	@# Remove unix sockets from previous run
	@-rm -f /tmp/erizo*.sock
	export LD_LIBRARY_PATH=$(LICODE_LIBDIR) && \
	export LICODE_LIBDIR=$(LICODE_LIBDIR) && \
	export PATH=$(NODEJS_BINDIR):$$PATH && \
	cd $(LICODE_SRCDIR)/erizo_controller/erizoController && \
		node erizoController.js
devel_runErizo: nuve.js erizoAPI runErizo


runOye:
	@echo " * Start Oye"
	@# Remove unix sockets from previous run
	@-rm -f /tmp/oye*.sock
	export PORT=3004 && \
	export OYE_HOME=$(MY_DIR) && \
	export LICODE_LIBDIR=$(LICODE_LIBDIR) && \
	export PATH=$(NODEJS_BINDIR):$$PATH && \
	node server.js $(PORT)
devel_runOye: nuve.js erizo.js erizoAPI runOye


prepare:
	@mkdir -p $(LICODE_LIBDIR)


deploy: services iptables nginx

services:
	#
	# Install nginx init script
	#
	cp raspbian/start-scripts/init.d/nginx /etc/init.d/nginx
	#
	# Create licode_config symlink
	#
	if [ ! -e "vendor/licode/licode_config.js" ]; then \
		ln -s `pwd`/config/licode_config.js `pwd`/vendor/licode/ ;\
	fi

iptables:
	#
	# Reload firewall rules
	#
	cp raspbian/iptables/rules.* /etc/iptables/
	iptables-restore < /etc/iptables/rules.v4

nginx:
	#
	# Reload nginx.conf
	#
	cp raspbian/nginx/nginx.conf /opt/nginx/conf/
	service nginx reload


clean:
	@if [ "$(LICODE_SRCDIR)/erizo" != "" ]; then \
		rm -rf $(LICODE_SRCDIR)/erizo/build; fi
	@if [ "$(LICODE_SRCDIR)/erizoAPI" != "" ]; then \
		rm -rf $(LICODE_SRCDIR)/erizoAPI/build; fi
	@if [ "$(LICODE_SRCDIR)/erizo_controller/erizoClient/dist" != "" ]; then \
		rm -f $(LICODE_SRCDIR)/erizo_controller/erizoClient/dist/*.js; \
		rm -rf $(LICODE_SRCDIR)/erizo_controller/erizoClient/build; \
	fi
	@if [ "$(LICODE_SRCDIR)/nuve/nuveClient/dist" != "" ]; then \
		rm -rf $(LICODE_SRCDIR)/nuve/nuveClient/dist; \
		rm -rf $(LICODE_SRCDIR)/nuve/nuveClient/build; \
	fi


help:
	@echo "Main build targets:"
	@echo
	@echo "    nuve"
	@echo "    erizo"
	@echo "    all            -- compile all of the above"
	@echo "    clean          -- remove compiler output files"
	@echo
	@echo "Main runtime targets:"
	@echo
	@echo "    runNuve        -- node.js http://localhost:3000"
	@echo "    runErizo       -- socket.io ws://localhost:8080"
	@echo "    runOye         -- node.js http://localhost:3004"
	@echo
	@echo "Other:"
	@echo
	@echo "    services       -- deploy /etc/init.d scripts"
	@echo "    iptables       -- deploy iptables rules"
	@echo "    nginx          -- deploy nginx.conf"
	@echo


.PHONY: run help services iptables nginx deploy
