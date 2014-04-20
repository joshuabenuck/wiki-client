# See fed.wiki.org/about-factory-plugin.html

neighborhood = require './neighborhood'

emit = ($item, item) ->
  $item.append '<p>Double-Click to Edit<br>Drop Text or Image to Insert</p>'
  showMenu = ->
    menu = $item.find('p').append "<br>Or Choose a Plugin"
    menu.append (left = $ """<div style="text-align:left; padding-left: 40%"></div>""")
    menu = left
    menuItem = (title, name) ->
      menu.append """
        <li><a class="menu" href="#" title="#{title}">#{name}</a></li>
      """
    if Array.isArray window.catalog
      menuItem(info.title, info.name) for info in window.catalog
    else  # deprecated
      menuItem(info.menu, name) for name, info of window.catalog
    menu.find('a.menu').click (evt)->
      $item.removeClass('factory').addClass(item.type=evt.target.text.toLowerCase())
      $item.unbind()
      wiki.textEditor $item, item

  showPrompt = ->
    $item.append "<p>#{wiki.resolveLinks(item.prompt)}</b>"

  if item.prompt
    showPrompt()
  else if window.catalog?
    showMenu()
  else
    $.getJSON '/system/factories.json', (data) ->
      window.catalog = data
      showMenu()

bind = ($item, item) ->

  syncEditAction = () ->
    wiki.log 'factory item', item
    $item.empty().unbind()
    $item.removeClass("factory").addClass(item.type)
    $page = $item.parents('.page:first')
    try
      $item.data 'pageElement', $page
      $item.data 'item', item
      wiki.getPlugin item.type, (plugin) ->
        plugin.emit $item, item
        plugin.bind $item, item
    catch err
      $item.append "<p class='error'>#{err}</p>"
    wiki.pageHandler.put $page, {type: 'edit', id: item.id, item: item}

  $item.dblclick ->
    $item.removeClass('factory').addClass(item.type='paragraph')
    $item.unbind()
    wiki.textEditor $item, item

  $item.bind 'dragenter', (evt) -> evt.preventDefault()
  $item.bind 'dragover', (evt) -> evt.preventDefault()
  $item.bind "drop", (dropEvent) ->

    punt = (data) ->
      item.prompt = "<b>Unexpected Item</b><br>We can't make sense of the drop.<br>#{JSON.stringify data}<br>Try something else or see [[About Factory Plugin]]."
      data.userAgent = navigator.userAgent
      item.punt = data
      wiki.log 'factory punt', dropEvent
      syncEditAction()

    readFile = (file) ->
      if file?
        [majorType, minorType] = file.type.split("/")
        reader = new FileReader()
        if majorType == "image"
          reader.onload = (loadEvent) ->
            item.type = 'image'
            item.url = loadEvent.target.result
            item.caption ||= "Uploaded image"
            syncEditAction()
          reader.readAsDataURL(file)
        else if majorType == "text"
          reader.onload = (loadEvent) ->
            result = loadEvent.target.result
            if minorType == 'csv'
              item.type = 'data'
              item.columns = (array = csvToArray result)[0]
              item.data = arrayToJson array
              item.text = file.fileName
            else
              item.type = 'paragraph'
              item.text = result
            syncEditAction()
          reader.readAsText(file)
        else
          punt
            number: 1
            name: file.fileName
            type: file.type
      else
        punt
          number: 2
          types: dropEvent.originalEvent.dataTransfer.types

    dropEvent.preventDefault()
    dropEvent.stopPropagation()
    if (dt = dropEvent.originalEvent.dataTransfer)?
      if dt.types? and ('text/uri-list' in dt.types or 'text/x-moz-url' in dt.types) and not ('Files' in dt.types)
        url = dt.getData 'URL'
        if found = url.match /^http:\/\/([a-zA-Z0-9:.-]+)(\/([a-zA-Z0-9:.-]+)\/([a-z0-9-]+(_rev\d+)?))+$/
          wiki.log 'factory drop url', found
          [ignore, origin, ignore, item.site, item.slug, ignore] = found
          if $.inArray(item.site,['view','local','origin']) >= 0
            item.site = origin
          $.getJSON "http://#{item.site}/#{item.slug}.json", (remote) ->
            wiki.log 'factory remote', remote
            item.type = 'reference'
            item.title = remote.title || item.slug
            item.text = wiki.createSynopsis remote
            syncEditAction()
            neighborhood.registerNeighbor item.site if item.site?
        else
          punt
            number: 4
            url: url
            types: dt.types
      else if 'Files' in dt.types
        readFile dt.files[0]
      else
        punt
          number: 5
          types: dt.types
    else
      punt
        number: 6
        trouble: "no data transfer object"

# from http://www.bennadel.com/blog/1504-Ask-Ben-Parsing-CSV-Strings-With-Javascript-Exec-Regular-Expression-Command.htm
# via http://stackoverflow.com/questions/1293147/javascript-code-to-parse-csv-data

csvToArray = (strData, strDelimiter) ->
  strDelimiter = (strDelimiter or ",")
  objPattern = new RegExp(("(\\" + strDelimiter + "|\\r?\\n|\\r|^)" + "(?:\"([^\"]*(?:\"\"[^\"]*)*)\"|" + "([^\"\\" + strDelimiter + "\\r\\n]*))"), "gi")
  arrData = [ [] ]
  arrMatches = null
  while arrMatches = objPattern.exec(strData)
    strMatchedDelimiter = arrMatches[1]
    arrData.push []  if strMatchedDelimiter.length and (strMatchedDelimiter isnt strDelimiter)
    if arrMatches[2]
      strMatchedValue = arrMatches[2].replace(new RegExp("\"\"", "g"), "\"")
    else
      strMatchedValue = arrMatches[3]
    arrData[arrData.length - 1].push strMatchedValue
  arrData

arrayToJson = (array) ->
  cols = array.shift()
  rowToObject = (row) ->
    obj = {}
    for [k, v] in _.zip(cols, row)
      obj[k] = v if v? && (v.match /\S/) && v != 'NULL'
    obj
  (rowToObject row for row in array)

module.exports = {emit, bind}