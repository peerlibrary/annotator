class ImageHighlight extends Annotator.Highlight
  # Create annotorious shape styles
  invisibleStyle:
    outline: undefined
    hi_outline: undefined
    stroke: undefined
    hi_stroke: undefined
    fill: undefined
    hi_fill: undefined

  defaultStyle:
    outline: '#000000'
    hi_outline: '#000000'
    stroke: '#ffffff'
    hi_stroke: '#fff000'
    fill: undefined
    hi_fill: undefined

  highlightStyle:
    outline: '#000000'
    hi_outline: '#000000'
    stroke: '#fff000'
    hi_stroke: '#ff7f00'
    fill: undefined
    hi_fill: undefined

  @Annotator = Annotator
  @$ = Annotator.$

  constructor: (anchor, pageIndex, image, shape, geometry, @annotorious) ->
    super anchor, pageIndex

    @$ = ImageHighlight.$
    @Annotator = ImageHighlight.Annotator

    @visibleHighlight = false
    @active = false
    # using the image, shape, geometry arguments.
    @annotoriousAnnotation =
      text: @annotation.text
      id: @annotation.id
      temporaryID: @annotation.temporaryImageID
      source: image.src
      highlight: this

    if @annotation.temporaryImageID
      @annotoriousAnnotation = @annotorious.updateAnnotationAfterCreatingAnnotatorHighlight @annotoriousAnnotation
    else
      @annotorious.addAnnotationFromHighlight @annotoriousAnnotation, image, shape, geometry, @defaultStyle

    @oldID = @annotation.id
    @_image = @annotorious.getImageForAnnotation @annotoriousAnnotation
    # TODO: prepare event handlers that call @annotator's
    # onAnchorMouseover, onAnchorMouseout, onAnchorMousedown, onAnchorClick
    # methods, with the appropriate list of annotations

  # React to changes in the underlying annotation
  annotationUpdated: ->
    @annotoriousAnnotation.text = @annotation.text
    @annotoriousAnnotation.id = @annotation.id
    if @oldID != @annotation.id then @annotoriousAnnotation.temporaryID = undefined
    @annotation.temporaryImageID = undefined

  # Remove all traces of this hl from the document
  removeFromDocument: ->
    @annotorious.deleteAnnotation @annotoriousAnnotation
    # TODO: kill this highlight

  # Is this a temporary hl?
  isTemporary: -> @_temporary

  # Mark/unmark this hl as temporary
  setTemporary: (value) ->
    @_temporary = value

  # Mark/unmark this hl as active
  setActive: (value) ->
    # TODO: Consider alwaysonannotation
    @active = value
    @annotorious.drawAnnotationHighlight @annotoriousAnnotation, @visibleHighlight

  _getDOMElements: -> @_image

  # Get the Y offset of the highlight. Override for more control
  getTop: -> @$(@_getDOMElements()).offset().top + @annotoriousAnnotation.heatmapGeometry.y

  # Get the height of the highlight. Override for more control
  getHeight: -> @annotoriousAnnotation.heatmapGeometry.h

  # Scroll the highlight into view. Override for more control
  scrollTo: -> @$(@_getDOMElements()).scrollintoview()

  # Scroll the highlight into view, with a comfortable margin.
  # up should be true if we need to scroll up; false otherwise
  paddedScrollTo: (direction) -> @scrollTo()
    # TODO; scroll to this, with some padding

  setVisibleHighlight: (state) ->
    @visibleHighlight = state
    if state
      @annotorious.updateShapeStyle @annotoriousAnnotation, @highlightStyle
    else
      @annotorious.updateShapeStyle @annotoriousAnnotation, @defaultStyle
    @annotorious.drawAnnotationHighlight @annotoriousAnnotation, @visibleHighlight

class ImageAnchor extends Annotator.Anchor

  constructor: (annotator, annotation, target,
      startPage, endPage, quote, @image, @shape, @geometry, @annotorious) ->

    super annotator, annotation, target, startPage, endPage, quote

  # This is how we create a highlight out of this kind of anchor
  _createHighlight: (page) ->

    # TODO: compute some magic from the initial data, if we have to
    #_doMagic()

    # Create the highlight
    new ImageHighlight this, page,
      @image, @shape, @geometry, @annotorious


# Annotator plugin for image annotations
class Annotator.Plugin.ImageAnchors extends Annotator.Plugin

  pluginInit: ->
    # Initialize whatever we have to
    @highlightType = 'ImageHighlight'

    # Collect the images within the wrapper
    @images = {}
    wrapper = @annotator.wrapper[0]
    @imagelist = $(wrapper).find('img')
    for image in @imagelist
      @images[image.src] = image

    # TODO init stuff, boot up other libraries,
    # Create the required UI, etc.
    @annotorious = new Annotorious.ImagePlugin wrapper, {}, this, @imagelist

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

    # Reacting to always-on-highlights mode
    @annotator.subscribe "setVisibleHighlights", (state) =>
      imageHighlights = @annotator.getHighlights().filter( (hl) -> hl instanceof ImageHighlight )
      for hl in imageHighlights
        hl.setVisibleHighlight state

  # This method is used by Annotator to attempt to create image anchors
  createImageAnchor: (annotation, target) =>
    # Fetch the image selector
    selector = @annotator.findSelector target.selector, "ShapeSelector"

    # No image selector, no image anchor
    return unless selector?

    # Find the image / verify that it exists
    # TODO: Maybe store image hash and compare them.
    image = @images[selector.source]

    # If we can't find the image, return null.
    return null unless image

    # Return an image anchor
    new ImageAnchor @annotator, annotation, target, # Mandatory data
      0, 0, '', # Page numbers. If we want multi-page (=pdf) support, find that out
      image, selector.shapeType, selector.geometry, @annotorious

  # This method is triggered by Annotorious to create image annotation
  annotate: (source, shape, geometry, tempID) ->
    # Prepare a target describing selection

    # Prepare data for Annotator about the selected target
    event =
      targets: [
        source: annotator.getHref()
        selector: [
          type: "ShapeSelector"
          source: source
          shapeType: shape
          geometry: geometry
        ]
      ]

    # Store the received temporary ID
    @pendingID = tempID

    # Trigger the creation of a new annotation
    @annotator.onSuccessfulSelection event, true

  # This method is triggered by Annotorious to show a list of annotations
  showAnnotations: (annotations) =>
    return unless annotations.length
    @annotator.onAnchorMousedown annotations, @highlightType
    @annotator.onAnchorClick annotations, @highlightType
