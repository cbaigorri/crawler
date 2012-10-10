###
Module Dependencies
###

request = require 'request'
jsdom = require 'jsdom'


###
Debugging
for p, i in process.argv
  console.log i, p
###

###
Validation
###

validUriExp = /// ^ (
  (https?://)?                                    # protocol
  ((([a-z\d]([a-z\d-]*[a-z\d])*)\.)+[a-z]{2,}|    # domain name
  ((\d{1,3}\.){3}\d{1,3}))                        # OR ip (v4) address
  (\:\d+)?(/[-a-z\d%_.~+]*)*                      # port and path
  (\?[;&a-z\d%_.~+=-]*)?                          # query string
  (\#[-a-z\d_]*)?$                                # fragment locater
) ///i

if process.argv.length > 1
  seed = process.argv[2]
  valid = if validUriExp.test seed then true else ///localhost///.test seed
else
  valid = false

if !valid 
  console.error 'Invalid URI!'
  process.exit 1


###
Hash table
ported from: http://www.mojavelinux.com/articles/javascript_hashes.html
###

HashTable = (obj) ->

  @length = 0
  @items = {}

  for p of obj
    if obj.hasOwnProperty(p)
      @items[p] = obj[p]
      @length++

  @setItem = (key, value) ->
    previous = `undefined`
    if @hasItem(key)
      previous = @items[key]
    else
      @length++
    @items[key] = value
    previous

  @getItem = (key) ->
    (if @hasItem(key) then @items[key] else `undefined`)

  @hasItem = (key) ->
    @items.hasOwnProperty key
  
  @removeItem = (key) ->
    if @hasItemm(key)
      previous = @items[key]
      @length--
      delete @items[key]
      
      previous
    else
      `undefined`

  @keys = ->
    keys = []
    for k of @items
      keys.push k  if @hasItem(k)
    keys

  @values = ->
    values = []
    for k of @items
      values.push @items[k]  if @hasItem(k)
    values

  @each = (fn) ->
    for k of @items
      fn k, @items[k]  if @hasItem(k)
  
  @clear = ->
    @items = {}
    @length = 0

  @


###
Initiate crawling
###

protocol = undefined
host = undefined
red = "\u001b[31m"
green = "\u001b[32m"
yellow = "\u001b[33m"
reset = "\u001b[0m"

# load a url
loadUrl = (url) ->
  
  if url is undefined
    console.log reset + 'FINISHED'
    return

  request url, (error, response, body) -> 
    # check for errors
    if error
      console.error red + 'An error occurred!', error
      links.setItem url, { error : error }
    
    # set some variables
    if protocol is `undefined` then protocol = response.request.uri.protocol
    if host is `undefined` then host = response.request.uri.host

    # record the response
    links.setItem url, { status : response.statusCode, 'content-type' : response.headers['content-type'] }
    
    if response.statusCode is 404
      console.log red + url, links.getItem(url)
    else if response.statusCode is 200
      console.log green + url, links.getItem(url)
    else 
      console.log yellow + url, links.getItem(url)

    # if this is html then parse links
    if response.headers['content-type'] is 'text/html' and !isExternal(seed, url) and response.statusCode isnt 404 
      $protocol = protocol
      $host = host
      # load the page
      jsdom.env url, ["http://code.jquery.com/jquery.js"], (errors, window) ->
        
        # parse the links
        $links = links
        $ = window.$
        window.$("a").each ->
          $uri = $(this).attr('href')
          if isAbsolute $uri then $uri = protocol + '//' + host + $uri
          if isRelative $uri
            path = response.request.uri.path.substring(0, response.request.uri.path.lastIndexOf('/'))
            $uri = protocol + '//' + host + path + '/' + $uri
          if $uri isnt "" and $uri.charAt(0) isnt '#' and !$links.hasItem $uri then $links.setItem $uri, {}

        # get the next link
        loadUrl getNextLink()
    else
      # get the next link
      loadUrl getNextLink()

    # status code is 200
    #if response.statusCode is 200 and response.headers['content-type'] is 'text/html'


# init the has table
links = new HashTable

# start the cycle
loadUrl seed

# get the next link
getNextLink = ->
  nextlink = undefined
  links.each (k, item) ->
    nextlink = k  if item.status is `undefined` and nextlink is `undefined`
  nextlink


# check if the link is external
isExternal = (seed, url) ->
  exp = /^([^:\/?#]+:)?(?:\/\/([^\/?#]*))?([^?#]+)?(\?[^#]*)?(#.*)?/
  match = seed.match(exp)
  match2 = url.match(exp)
  return true  if typeof match[1] is "string" and match[1].length > 0 and match[1].toLowerCase() isnt match2[1]
  return true  if typeof match[2] is "string" and match[2].length > 0 and match[2].toLowerCase() isnt match2[2]
  false


# check if the link is relative
isRelative = (url) ->
  url.charAt(0) isnt "" and url.charAt(0) isnt "#" and url.charAt(0) isnt "/" and url.indexOf("//") is -1


# check if the link is absolute
isAbsolute = (url) ->
  url.charAt(0) is "/" and ( url.indexOf("//") is -1 or url.indexOf("//") > url.indexOf("#") or url.indexOf("//") > url.indexOf("?") )


###

A list of unvisited URLs - seed this with one or more starting pages
A list of visited URLs - so you don't go around in circles
A set of rules for URLs you're not interested in - so you don't index the whole Internet

while(list of unvisited URLs is not empty) {
    take URL from list
    fetch content
    record whatever it is you want to about the content
    if content is HTML {
        parse out URLs from links
        foreach URL {
           if it matches your rules
              and it's not already in either the visited or unvisited list
              add it to the unvisited list
        }
    }
}
###