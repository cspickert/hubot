URL_RE = /(\b(https?|ftp|file):\/\/[-A-Z0-9+&@#\/%?=~_|!:,.;]*[-A-Z0-9+&@#\/%=~_|])/ig
CACHE_MAX_SIZE = 50
SOCKET_IMAGE_EVENT = 'hubot_img_stream_image'

class ImageStream
  constructor: (@robot, port) ->
    @cache = []
    @io = (require 'socket.io').listen @robot.server
    
    @io.configure =>
      @io.set "transports", ["xhr-polling"]
      @io.set "polling duration", 10
      @io.set "log level", 1
    
    @io.sockets.on 'connection', (socket) =>
      for image in @cache
        socket.emit SOCKET_IMAGE_EVENT, image

  receive: (url, user) ->
    image = {'url': url, 'user': user, 'date': new Date}
    if @cache.length > CACHE_MAX_SIZE
      @cache.splice 0, 1
    @cache.push image
    @io.sockets.emit SOCKET_IMAGE_EVENT, image

module.exports = (robot) ->
  imageStream = new ImageStream robot
  
  if not process.env.HEROKU_URL?
    serverAddress = robot.server.address()
    serverURL = "http://#{serverAddress.address}:#{serverAddress.port}"
  else
    serverURL = process.env.HEROKU_URL
  
  matchImageURL = (url) -> (url.match /\b(?:jpe?g|png|gif)\b/i)?
  
  robot.hear URL_RE, (res) ->
    for url in res.match
      if matchImageURL(url)?
        imageStream.receive url, res.message.user.name

  oldSend = robot.adapter.send
  newSend = (user, strings...) ->
    console.log arguments
    for str in strings
      urlMatches = str.match URL_RE
      for url in urlMatches
        if matchImageURL(url)?
          imageStream.receive url, robot.name
    oldSend.apply(robot.adapter, arguments)
  robot.adapter.send = newSend

  robot.router.get '/hubot/img_stream', (req, res) ->
    res.writeHead 200,
      'Content-Type': 'text/html; charset=utf-8'
    res.write """
    <!DOCTYPE html>
    <html>
    <head>
      <script src="#{serverURL}/socket.io/socket.io.js"></script>
      <script>
        var createImageLink = function (url) {
          var img = document.createElement("img");
          img.src = url;
          var a = document.createElement("a");
          a.href = url;
          a.appendChild(img);
          return a;
        };
        
        var createImageHeader = function (user, date) {
          var userSpan = document.createElement("span"),
              dateSpan = document.createElement("span");
          userSpan.className = "user";
          dateSpan.className = "date";
          userSpan.innerHTML = user;
          dateSpan.innerHTML = date.toString();
          
          var headerDiv = document.createElement("div");
          headerDiv.appendChild(userSpan);
          headerDiv.appendChild(dateSpan);
          headerDiv.className = "header";
          
          return headerDiv;
        };
        
        var createImageItem = function (imageObject) {
          var user = imageObject.user,
              url = imageObject.url,
              date = imageObject.date;
          var div = document.createElement("div");
          var header = createImageHeader(user, date);
          var a = createImageLink(url);
          div.appendChild(header);
          div.appendChild(a);
          div.className = "image";
          return div;
        };
        
        var socket = io.connect("#{serverURL}");
        socket.on("#{SOCKET_IMAGE_EVENT}", function (image) {
          var container = document.getElementById("images"),
              item = createImageItem(image);
          if (container.firstChild) {
            container.insertBefore(item, container.firstChild);
          } else {
            container.appendChild(item);
          }
        });
      </script>
      <style type="text/css">
        #images {
          min-width: 320px;
          max-width: 600px;
          margin: 0 auto;
        }
        #images .image {
          padding-bottom: 20px;
        }
        #images .image .header {
          width: 100%;
          float: left;
          margin-bottom: 8px;
          background-color: #ECF1EF;
          font: 14px Courier, monospace;
        }
        #images .image .header span {
          display: block;
          width: 49%;
          padding: 0;
          margin: 0;
        }
        #images .image .header .user {
          float: left;
          font-weight: bold;
        }
        #images .image .header .date {
          float: right;
          text-align: right;
        }
        #images .image div, #image a {
          display: block;
        }
        #images .image img {
          display: block;
          max-height: 320px;
          max-width: 100%;
          margin: 0 auto;
          padding-bottom: 10px;
        }
      </style>
    </head>
    <body>
      <div id="images">
      </div>
    </body>
    </html>
    """
    res.end()
