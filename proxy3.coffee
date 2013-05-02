net=require 'net'
http=require 'http'
https=require 'https'
util=require 'util'
url=require 'url'

https.globalAgent.options.secureProtocol='SSLv3_method'

makeProxy=->http.createServer()
  .on 'connection', (conn)->
    ad46=net.isIP(ad=conn.remoteAddress)
    console.log "connection: (#{ad46}) #{ad}"
    unless (ad46==4 && ad=='127.0.0.1') || (ad46==6 && ad=='::1')
      console.log 'not local, banned'
      conn.end()
      return
  .on 'request', (l_req, l_res)->
    opt=url.parse l_req.url.replace(/^http/, 'https')
    opt.protocol='https:'
    opt.method=l_req.method

    console.log '-> ' + l_req.url

    h_req=https.request opt, (h_res)->
      console.log '<-'
      console.log util.inspect h_res.headers

      l_res.writeHead h_res.statusCode, h_res.headers
      h_res.pipe l_res
    
    l_req.pipe h_req
    

makeProxy().listen(8888)

process.on 'uncaughtException', (err)->
  console.error err
