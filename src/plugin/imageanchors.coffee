class ImageHighlight extends Annotator.Highlight

  constructor: (anchor, pageIndex, image, shape, geometry) ->
    super anchor, pageIndex

    # TODO: create the actual highlight over the image,
    # using the image, shape, geometry arguments.

    # TODO: prepare event handlers that call @annotator's
    # onAnchorMouseover, onAnchorMouseout, onAnchorMousedown, onAnchorClick
    # methods, with the appropriate list of annotations

  # Is this a temporary hl?
  isTemporary: -> @_temporary

  # Mark/unmark this hl as active
  setTemporary: (value) ->
    @_temporary = value
    if value
      # TODO: mark it as a temporary HL
    else
      # TODO: unmark it as a temporary HL

  # Mark/unmark this hl as active
  setActive: (value) ->
    if value
      # TODO: mark it as an active HL
    else
      # TODO: unmark it as an active HL

  # Remove all traces of this hl from the document
  removeFromDocument: ->
    # TODO: kill this highlight

  _getDOMElements: ->
    # TODO: do we have actual HTML elements for the individual highlights over
    # the images?
    #
    # If yes, then return them here, and remove everything from below
    # If no, remove this method, and implement the ones below

  # Get the Y offset of the highlight. Override for more control
  getTop: -> # TODO: get Y offset

  # Get the height of the highlight. Override for more control
  getHeight: -> # TODO: get height

  # Get the bottom Y offset of the highlight. Override for more control.
  getBottom: -> # TODO: get bottom

  # Scroll the highlight into view. Override for more control
  scrollTo: -> # TODO: scroll to this

  # Scroll the highlight into view, with a comfortable margin.
  # up should be true if we need to scroll up; false otherwise
  paddedScrollTo: (direction) ->
    # TODO; scroll to this, with some padding

class ImageAnchor extends Annotator.Anchor

  constructor: (annotator, annotation, target,
      startPage, endPage, @image, @shape, @geometry) ->

    super annotator, annotation, target, startPage, endPage

  # This is how we create a highlight out of this kind of anchor
  _createHighlight: (page) ->

    # TODO: compute some magic from the initial data, if we have to
    _doMagic()

    # Create the highlight
    new ImageHighlight this, page,
      @image, @shape, @geometry


# Annotator plugin for image annotations
class Annotator.Plugin.ImageAnchors extends Annotator.Plugin

  pluginInit: ->
    # Initialize whatever we have to

    # Collect the images within the wrapper
    @images = {}
    for image in $(@annotator.wrapper[0]).find('img')
      @images[image.src] = image

    # TODO init stuff, boot up other libraries,
    # create the required UI, etc.

    # Register the image anchoring strategy
    @annotator.anchoringStrategies.push
      # Image anchoring strategy
      name: "image"
      code: this.createImageAnchor


    # Upon creating an annotation,
    @annotator.on 'beforeAnnotationCreated', (annotation) =>
     # Check whether we have triggered it
     if @pendingID
       # Yes, this is a newly created image annotation
       # Pass back the ID, so that Annotorious can recognize it
       annotation.temporaryImageID = @pendingID
       delete @pendingID

  # This method is used by Annotator to attempt to create image anchors
  createImageAnchor: (annotation, target) =>
    # Fetch the image selector
    selector = @annotator.findSelector target.selector, "ShapeSelector"

    # No image selector, no image anchor
    return unless selector?

    # Find the image / verify that it exists
    image = @images[selector.source]

    # If we can't find the image, return null.
    return null unless image

    # Return an image anchor
    new ImageAnchor @annotator, annotation, target, # Mandatory data
      0, 0, # Page numbers. If we want multi-page (=pdf) support, find that out
      image, selector.shapeType, selector.geometry

  # This method is triggered by Annotorious to create image annotation
  # TODO: call this from Annotorious
  annotate: (image, shape, geometry, tempId) ->
    # Prepare a target describing selection

    # Prepare data for Annotator about the selected target
    event =
      targets: [
        source: annotator.getHref()
        selector: [
          type: "ShapeSelector"
          image: image
          shapeType: shape
          geometry: geometry
        ]
      ]

    # Store the received temporary ID
    @pendingID = tempID

    # Trigger the creation of a new annotation
    @annotator.onSuccessfulSelection event, true
