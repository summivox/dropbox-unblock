net = require 'net'
http = require 'http'
{parse} = require 'url'

# default port of proxy
PORT = 8888

# header entries to strip from HTTP {GET, POST}
BAN_LIST = [
  'connection'
  'keep-alive'
  'host'
]

# response to HTTP CONNECT
CONN_RESPONSE = 'HTTP/1.1 200 Connection Established\r\nConnection: Close\r\n\r\n'

isLocal = (ip) ->
  ip46 = net.isIP ip
  (ip46 == 4 && ip == '127.0.0.1') || (ip46 == 6 && ip == '::1')

addHttp = (url) ->
  if url.match /^http:\/\// then url else 'http:\/\/' + url

makeProxy = -> http.createServer()
  .on 'connection', (conn) ->
    ip = conn.remoteAddress
    if !isLocal ip
      console.log 'not local, banned'
      conn.end()
    else
      console.log '### start'
  .on 'close', ->
    console.log '### stop'

  .on 'connect', (req, local, head) ->
    {hostname, port} = parse addHttp req.url
    console.log ">>> connect #{hostname}:#{port}"
    remote = net.connect port, hostname, ->
      console.log "<<< connect"
      local.write CONN_RESPONSE
      remote.write head
      local.pipe remote
      remote.pipe local

  .on 'request', (l_to_me, me_to_l) ->
    {method, url} = l_to_me
    {hostname, port, path} = urlp = parse url
    console.log ">>> #{method} #{hostname}:#{port}#{path}"

    # pre-filter headers
    headers = {'connection': 'close'}
    for key, value of l_to_me.headers
      if BAN_LIST.every((ban) -> !(key.match ///#{ban}///i))
        headers[key] = value

    me_to_r = http.request {
      hostname, port, method, path, headers
    }, (r_to_me) ->
      console.log "<<< #{method} #{r_to_me.statusCode}"
      me_to_l.writeHead? r_to_me.statusCode, r_to_me.headers
      r_to_me.pipe me_to_l

    # post-filter headers
    me_to_r.removeHeader ban for ban in BAN_LIST

    l_to_me.pipe me_to_r

# bootstrap
process.on 'uncaughtException', (err) -> console.error "ERR #{err}"
if isNaN port = parseInt process.argv.pop() then port = PORT
makeProxy().listen(port)
console.log "=== dropbox-unblock running at 127.0.0.1:#{port} ==="
