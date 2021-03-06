# This plugin implements the UI code for creating text annotations
class Annotator.Plugin.TextAnchors extends Annotator.Plugin

  # Plugin initialization
  pluginInit: ->
    @Annotator = Annotator
    @$ = Annotator.$

    # Register the event handlers required for creating a selection
    $(document).bind({
      "mouseup.annotator": @checkForEndSelection
    })

    # React to the enableAnnotation event
    @annotator.subscribe "enableAnnotating", (value) => if value
      # If annotation is now enable, check if we have a valid selection
      setTimeout @checkForEndSelection, 500

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

  # Verifies whether or not a given part of the DOM is supposed
  # to be annotated. (Parts of the DOM which are part of annotator
  # itself are not supposed to be annotated.)
  isThisSupposedToBeAnnotated: (node) ->

    # First, look up the real top container of this node,
    # because some highlights might be in the way

    goOn = true
    while goOn
      goOn = false
      for h in @annotator.highlighters
        if h.isInstance?(node)
          node = h.getIndependentParent node
          goOn = true
          break

    # Now that we know which element should we look at, check
    # if it's part of Annotator
    not @annotator.isAnnotator node

  # This is called then the mouse is released.
  # Checks to see if a selection has been made on mouseup and if so,
  # calls Annotator's onSuccessfulSelection method.
  # Also resets the @mouseIsDown property.
  #
  # event - The event triggered this. Usually it's a mouseup Event,
  #         but that's not necessary. The coordinates will be used,
  #         if they are present. If the event (or the coordinates)
  #         are missing, new coordinates will be generated, based on the
  #         selected ranges.
  #
  # Returns nothing.
  checkForEndSelection: (event = {}) =>
    @annotator.mouseIsDown = false

    # We don't care about the adder button click
    return if @annotator.inAdderClick

    # Get the currently selected ranges.
    selectedRanges = @_getSelectedRanges()

    # Return if nothing is selected
    unless selectedRanges.length
      @annotator.onFailedSelection event
      return

    # Check if it's legal to annotate these parts
    for range in selectedRanges
      return unless @isThisSupposedToBeAnnotated range.commonAncestor

    # Put the selected segments into the event
    event.segments = ({type: "text range", range: r} for r in selectedRanges)

    # Do we have valid page coordinates inside the event
    # which has triggered this function?
    unless event.pageX
      # No, we don't. Adding fake coordinates
      pos = selectedRanges[0].getEndCoords()
      event.pageX = pos.x
      event.pageY = pos.y #- window.scrollY

    # Notify annotator core about the successfull selection
    @annotator.onSuccessfulSelection event

