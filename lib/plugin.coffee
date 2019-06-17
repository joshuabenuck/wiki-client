# The plugin module manages the dynamic retrieval of plugin
# javascript including additional scripts that may be requested.

module.exports = plugin = {}

escape = (s) ->
  (''+s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#x27;')
    .replace(/\//g,'&#x2F;')

# define cachedScript that allows fetching a cached script.
# see example in http://api.jquery.com/jQuery.getScript/

cachedScript = (url, options) ->
  options = $.extend(options or {},
    dataType: "script"
    cache: true
    url: url
  )
  $.ajax options

scripts = []
getScript = plugin.getScript = (url, callback = () ->) ->
  # console.log "URL :", url, "\nCallback :", callback
  if url in scripts
    callback()
  else
    cachedScript url
      .done ->
        scripts.push url
        callback()
      .fail ->
        callback()

pluginsThatConsume = (capability) ->
  Object.keys(window.plugins).filter(plugin -> window.plugins[plugin].consumes)

bind = (pluginBind) ->
  fn($item, item) ->
    consumes = window.plugins[name].consumes
    producers = pluginsThatProduce(consumes)
    waitFor = Promise.resolve()
    # Wait for all items on the page that produce what we consume
    # before calling our bind method.
    if consumes
      if not producers
        console.log 'warn: no plugin register that produces', consumes
      deps = $page.find(consumes).map (_i, el) -> el.promise
      waitFor = Promise.all(deps)
    waitFor
      .then pluginBind($item, item)
      # After we bind, notify everyone that depends on us to reload
      .then ->
        return if not plugin.produces
        console.log 'notifying plugins that consume', plugin.produces
        tonotify = pluginsThatConsume(plugin.produces)
        tonotify.forEach (plugin) ->
          lineup.find('plugin of type plugin.name').forEach (pluginItem) ->
            plugin.do $item.empty(), pluginItem
      .catch (e) ->
        console.log 'plugin emit: unexpected error', e

plugin.get = plugin.getPlugin = (name, callback) ->
  return new Promise (resolve) ->
    resolve(window.plugins[name]) if window.plugins[name]
    getScript "/plugins/#{name}/#{name}.js", () ->
      return resolve(window.plugins[name]) if window.plugins[name]
      getScript "/plugins/#{name}.js", () ->
        resolve(window.plugins[name])
  .then (plugin) ->
    if not plugin.wrapped
      console.log 'wrapping plugin', name
      plugin.bind = bind(plugin.bind)
      plugin.wrapped = true
    callback plugin if callback

plugin.do = plugin.doPlugin = (div, item, done=->) ->
  error = (ex, script) ->
    div.append """
      <div class="error">
        #{escape item.text || ""}
        <button>help</button><br>
      </div>
    """
    if item.text?
      div.find('.error').dblclick (e) ->
        wiki.textEditor div, item
    div.find('button').on 'click', ->
      wiki.dialog ex.toString(), """
        <p> This "#{item.type}" plugin won't show.</p>
        <li> Is it available on this server?
        <li> Is its markup correct?
        <li> Can it find necessary data?
        <li> Has network access been interrupted?
        <li> Has its code been tested?
        <p> Developers may open debugging tools and retry the plugin.</p>
        <button class="retry">retry</button>
        <p> Learn more
          <a class="external" target="_blank" rel="nofollow"
          href="http://plugins.fed.wiki.org/about-plugins.html"
          title="http://plugins.fed.wiki.org/about-plugins.html">
            About Plugins
            <img src="/images/external-link-ltr-icon.png">
          </a>
        </p>
      """
      $('.retry').on 'click', ->
        if script.emit.length > 2
          script.emit div, item, ->
            script.bind div, item
            done()
        else
          script.emit div, item
          script.bind div, item
          done()

  div.data 'pageElement', div.parents(".page")
  div.data 'item', item
  plugin.get item.type, (script) ->
    try
      throw TypeError("Can't find plugin for '#{item.type}'") unless script?
      if script.emit.length > 2
        script.emit div, item, ->
          script.bind div, item
          done()
      else
        script.emit div, item
        script.bind div, item
        done()
    catch err
      console.log 'plugin error', err
      error(err, script)
      done()

plugin.registerPlugin = (pluginName,pluginFn)->
  window.plugins[pluginName] = pluginFn($)
