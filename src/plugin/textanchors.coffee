# This plugin implements the usual text anchor.
# Contains
#  * the the definitions of the corresponding selectors,
#  * the anchor class,
#  * the basic anchoring strategies

class TextPositionAnchor extends Annotator.Anchor

  @Annotator = Annotator

  constructor: (annotator, annotation, target,
      @start, @end, startPage, endPage,
      quote, diffHTML, diffCaseOnly) ->

    super annotator, annotation, target,
      startPage, endPage,
      quote, diffHTML, diffCaseOnly

    unless @start? then throw "start is required!"
    unless @end? then throw "end is required!"

    @Annotator = TextPositionAnchor.Annotator

  # This is how we create a highlight out of this kind of anchor
  _createHighlight: (page) ->

    # First calculate the ranges
    mappings = @annotator.domMapper.getMappingsForCharRange @start, @end, [page]

    # Get the wanted range
    realRange = mappings.sections[page].realRange

    # Get a BrowserRange
    browserRange = new @Annotator.Range.BrowserRange realRange

    # Get a NormalizedRange
    normedRange = browserRange.normalize @annotator.wrapper[0]

    # Create the highligh
    new @Annotator.TextHighlight this, page, normedRange

class Annotator.Plugin.TextAnchors extends Annotator.Plugin

  # Plugin initialization
  pluginInit: ->
    # We need dom-text-mapper
    unless @annotator.plugins.DomTextMapper
      throw "The TextAnchors Annotator plugin requires the DomTextMapper plugin."
    # We need text highlights
    unless @annotator.plugins.TextHighlights
      throw "The TextAnchors Annotator plugin requires the TextHighlights plugin."
    # Declare our conflict with the OldTextAnchors plugin
    if @annotator.plugins.OldTextAnchors
      throw "The TextAnchors Annotator plugin conflicts with the OldTextAnchors plugin."

    @Annotator = Annotator
    @$ = Annotator.$
        
    # Register our anchoring strategies
    @annotator.anchoringStrategies.push
      # Simple strategy based on DOM Range
      name: "range"
      code: @createFromRangeSelector

    @annotator.anchoringStrategies.push
      # Position-based strategy. (The quote is verified.)
      # This can handle document structure changes,
      # but not the content changes.
      name: "position"
      code: @createFromPositionSelector

    # Register the event handlers required for creating a selection
    $(@annotator.wrapper).bind({
      "mouseup": @checkForEndSelection
    })

    # Export this anchor type
    @annotator.TextPositionAnchor = TextPositionAnchor

    null


  # Code used to create annotations around text ranges =====================

  # Gets the current selection excluding any nodes that fall outside of
  # the @wrapper. Then returns and Array of NormalizedRange instances.
  #
  # Examples
  #
  #   # A selection inside @wrapper
  #   annotation.getSelectedRanges()
  #   # => Returns [NormalizedRange]
  #
  #   # A selection outside of @wrapper
  #   annotation.getSelectedRanges()
  #   # => Returns []
  #
  # Returns Array of NormalizedRange instances.
  _getSelectedRanges: ->
    selection = @Annotator.util.getGlobal().getSelection()

    ranges = []
    rangesToIgnore = []
    unless selection.isCollapsed
      ranges = for i in [0...selection.rangeCount]
        r = selection.getRangeAt(i)
        browserRange = new @Annotator.Range.BrowserRange(r)
        normedRange = browserRange.normalize().limit @annotator.wrapper[0]

        # If the new range falls fully outside the wrapper, we
        # should add it back to the document but not return it from
        # this method
        rangesToIgnore.push(r) if normedRange is null

        normedRange

      # BrowserRange#normalize() modifies the DOM structure and deselects the
      # underlying text as a result. So here we remove the selected ranges and
      # reapply the new ones.
      selection.removeAllRanges()

    for r in rangesToIgnore
      selection.addRange(r)

    # Remove any ranges that fell outside of @wrapper.
    @$.grep ranges, (range) ->
      # Add the normed range back to the selection if it exists.
      selection.addRange(range.toRange()) if range
      range

  # This is called then the mouse is released.
  # Checks to see if a selection has been made on mouseup and if so,
  # calls Annotator's onSuccessfulSelection method.
  # If @ignoreMouseup is set, will do nothing.
  # Also resets the @mouseIsDown property.
  #
  # event - A mouseup Event object.
  #
  # Returns nothing.
  checkForEndSelection: (event) =>
    @annotator.mouseIsDown = false

    # This prevents the note image from jumping away on the mouseup
    # of a click on icon.
    return if @annotator.ignoreMouseup

    # Get the currently selected ranges.
    selectedRanges = @_getSelectedRanges()

    for range in selectedRanges
      container = range.commonAncestor
      # TODO: what is selection ends inside a different type of highlight?
      if @Annotator.TextHighlight.isInstance container
        container = @Annotator.TextHighlight.getIndependentParent container
      return if @annotator.isAnnotator(container)

    if selectedRanges.length
      event.targets = (@getTargetFromRange(r) for r in selectedRanges)
      @annotator.onSuccessfulSelection event
    else
      @annotator.onFailedSelection event

  # Create a RangeSelector around a range
  _getRangeSelector: (range) ->
    sr = range.serialize @annotator.wrapper[0]

    type: "RangeSelector"
    startContainer: sr.startContainer
    startOffset: sr.startOffset
    endContainer: sr.endContainer
    endOffset: sr.endOffset

  # Create a TextQuoteSelector around a range
  _getTextQuoteSelector: (range) ->
    unless range?
      throw new Error "Called getTextQuoteSelector(range) with null range!"

    rangeStart = range.start
    unless rangeStart?
      throw new Error "Called getTextQuoteSelector(range) on a range with no valid start."
    startOffset = (@annotator.domMapper.getInfoForNode rangeStart).start
    rangeEnd = range.end
    unless rangeEnd?
      throw new Error "Called getTextQuoteSelector(range) on a range with no valid end."
    endOffset = (@annotator.domMapper.getInfoForNode rangeEnd).end
    quote = @annotator.domMapper.getCorpus()[startOffset .. endOffset-1].trim()
    [prefix, suffix] = @annotator.domMapper.getContextForCharRange startOffset, endOffset

    type: "TextQuoteSelector"
    exact: quote
    prefix: prefix
    suffix: suffix

  # Create a TextPositionSelector around a range
  _getTextPositionSelector: (range) ->
    startOffset = (@annotator.domMapper.getInfoForNode range.start).start
    endOffset = (@annotator.domMapper.getInfoForNode range.end).end

    type: "TextPositionSelector"
    start: startOffset
    end: endOffset

  # Create a target around a normalizedRange
  getTargetFromRange: (range) ->
    source: @annotator.getHref()
    selector: [
      @_getRangeSelector range
      @_getTextQuoteSelector range
      @_getTextPositionSelector range
    ]

  # Stratiges used for creating these anchors from saved data

  # Look up the quote from the appropriate selector
  getQuoteForTarget: (target) ->
    selector = @annotator.findSelector target.selector, "TextQuoteSelector"
    if selector?
      @annotator.normalizeString selector.exact
    else
      null

  # Create and anchor using the saved Range selector. The quote is verified.
  createFromRangeSelector: (annotation, target) ->
    selector = @findSelector target.selector, "RangeSelector"
    unless selector? then return null

    # Try to apply the saved XPath
    try
      normalizedRange = @Annotator.Range.sniff(selector).normalize @wrapper[0]
    catch error
      return null
    startInfo = @domMapper.getInfoForNode normalizedRange.start
    startOffset = startInfo.start
    endInfo = @domMapper.getInfoForNode normalizedRange.end
    endOffset = endInfo.end
    content = @domMapper.getCorpus()[startOffset .. endOffset-1].trim()
    currentQuote = @normalizeString content

    # Look up the saved quote
    savedQuote = @plugins.TextAnchors.getQuoteForTarget target
    if savedQuote? and currentQuote isnt savedQuote
      #console.log "Could not apply XPath selector to current document, " +
      #  "because the quote has changed. (Saved quote is '#{savedQuote}'." +
      #  " Current quote is '#{currentQuote}'.)"
      return null

    # Create a TextPositionAnchor from this range
    new TextPositionAnchor this, annotation, target,
      startInfo.start, endInfo.end,
      (startInfo.pageIndex ? 0), (endInfo.pageIndex ? 0),
      currentQuote

  # Create an anchor using the saved TextPositionSelector. The quote is verified.
  createFromPositionSelector: (annotation, target) ->
    selector = @findSelector target.selector, "TextPositionSelector"
    unless selector? then return null
    content = @domMapper.getCorpus()[selector.start .. selector.end-1].trim()
    currentQuote = @normalizeString content
    savedQuote = @plugins.TextAnchors.getQuoteForTarget target
    if savedQuote? and currentQuote isnt savedQuote
      # We have a saved quote, let's compare it to current content
      #console.log "Could not apply position selector" +
      #  " [#{selector.start}:#{selector.end}] to current document," +
      #  " because the quote has changed. " +
      #  "(Saved quote is '#{savedQuote}'." +
      #  " Current quote is '#{currentQuote}'.)"
      return null

    # Create a TextPositionAnchor from this data
    new TextPositionAnchor this, annotation, target,
      selector.start, selector.end,
      (@domMapper.getPageIndexForPos selector.start),
      (@domMapper.getPageIndexForPos selector.end),
      currentQuote

