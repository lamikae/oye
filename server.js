console.log("Node.js %s", process.version);
require("coffee-script");
require("./server/oye").listen(process.env.PORT || 3004);
