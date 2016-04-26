CocoView = require 'views/core/CocoView'
LevelComponent = require 'models/LevelComponent'
template = require 'templates/play/level/tome/spell_translation'
Range = ace.require('ace/range').Range
TokenIterator = ace.require('ace/token_iterator').TokenIterator
serializedClasses =
  Thang: require 'lib/world/thang'
  Vector: require 'lib/world/vector'
  Rectangle: require 'lib/world/rectangle'
  Ellipse: require 'lib/world/ellipse'
  LineSegment: require 'lib/world/line_segment'
utils = require 'core/utils'

module.exports = class SpellTranslationView extends CocoView
  className: 'spell-translation-view'
  template: template
  
  events:
    'mousemove': ->
      @$el.hide()

  constructor: (options) ->
    super options
    @ace = options.ace
    @thang = options.thang
    @spell = options.spell
    @supermodel = options.supermodel
    @globals = {} # TODO: Do I want this?
    
    lcs = @supermodel.getModels LevelComponent
    @componentTranslations = @supermodel.getModels(LevelComponent).reduce((acc, lc) ->
      for doc in (lc.get('propertyDocumentation') ? [])
        translated = utils.i18n(doc, 'name', null, false)
        acc[doc.name] = translated if translated isnt doc.name
        console.log translated, doc.name
      acc
    , {})
    
    console.log @componentTranslations
    
    @onMouseMove = _.throttle @onMouseMove, 25
    
  afterRender: ->
    super()
    @ace.on 'mousemove', @onMouseMove

  setTooltipText: (text) =>
    @$el.find('code').text text
    @$el.show().css(@pos)
    
  isIdentifier: (t) ->
    # TODO: This is actually all tokens
    t and (t.type in ['identifier', 'keyword'] or t.value is 'this' or @globals[t.value])
    
  onMouseMove: (e) =>
    return if @destroyed
    pos = e.getDocumentPosition()
    it = new TokenIterator e.editor.session, pos.row, pos.column
    endOfLine = it.getCurrentToken()?.index is it.$rowTokens.length - 1
    while it.getCurrentTokenRow() is pos.row and not @isIdentifier(token = it.getCurrentToken())
      break if endOfLine or not token  # Don't iterate beyond end or beginning of line
      it.stepBackward()
    unless token
      @word = null
      @update()
      return
    try
      # Ace was breaking under some (?) conditions, dependent on mouse location.
      #   with $rowTokens = [] (but should have things)
      start = it.getCurrentTokenColumn()
    catch error
      start = 0
    end = start + token.value.length
    console.log token
    if @isIdentifier(token)
      @word = token.value
      @markerRange = new Range pos.row, start, pos.row, end
      @reposition(e.domEvent)
    @update()
    
  reposition: (e) ->
    offsetX = e.offsetX ? e.clientX - $(e.target).offset().left
    offsetY = e.offsetY ? e.clientY - $(e.target).offset().top
    w = $(document).width()
    offsetX = w - $(e.target).offset().left - 300 if e.clientX + 300 > w
    @pos = {left: offsetX + 80, top: offsetY - 20}
    @$el.css(@pos)
    
  onMouseOut: ->
    @word = null
    @markerRange = null
    @update()
    
  update: ->
    i18nKey = 'code.'+@word
    translation = @componentTranslations[@word] or $.t(i18nKey)
    if @word and translation and translation isnt i18nKey
      @setTooltipText translation
      console.log "token:", @word, "translated:", translation
    else
      @$el.hide()

  destroy: ->
    @ace?.removeEventListener 'mousemove', @onMouseMove
    super()
