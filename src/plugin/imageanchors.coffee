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
    if @oldID != @annotation.id
      delete @annotoriousAnnotation.temporaryID
    delete @annotation.temporaryImageID

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
  setActive: (value, batch = false) ->
    # TODO: Consider alwaysonannotation
    @active = value
    unless batch
      @annotorious.drawAnnotationHighlights @annotoriousAnnotation.source, @visibleHighlight

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

  setVisibleHighlight: (state, batch = false) ->
    @visibleHighlight = state
    if state
      @annotorious.updateShapeStyle @annotoriousAnnotation, @highlightStyle
    else
      @annotorious.updateShapeStyle @annotoriousAnnotation, @defaultStyle

    unless batch
      @annotorious.drawAnnotationHighlights @annotoriousAnnotation.source, @visibleHighlight

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

    @Annotator = Annotator
    @$ = Annotator.$

    # Collect the images within the wrapper
    @images = {}
    @visibleHighlights = false
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

    # Reacting to always-on-highlights mode
    @annotator.subscribe "setVisibleHighlights", (state) =>
      @visibleHighlights = state
      imageHighlights = @annotator.getHighlights().filter( (hl) -> hl instanceof ImageHighlight )
      for hl in imageHighlights
        hl.setVisibleHighlight state, true

      for src, _ of @images
        @annotorious.drawAnnotationHighlights src, @visibleHighlights

    # Reacting to finalizeHighlights
    @annotator.subscribe "finalizeHighlights", =>
      for src, _ of @images
        try
          @annotorious.drawAnnotationHighlights src, @visibleHighlights
        catch error
          console.log "Error: failed to draw image highlights for", src
          console.log error.stack

  # This method is used by Annotator to attempt to create image anchors
  createImageAnchor: (annotation, target) =>
    # Prepare the deferred object
    dfd = @$.Deferred()

    # Fetch the image selector
    selector = @annotator.findSelector target.selector, "ShapeSelector"

    # No image selector, no image anchor
    unless selector?
      dfd.reject "no ImageSelector found"
      return dfd.promise()

    # Find the image / verify that it exists
    # TODO: Maybe store image hash and compare them.
    image = @images[selector.source]

    # If we can't find the image, we fail
    unless image
      dfd.reject ("No such image exists as " + selector.source)
      return dfd.promise()

    # Return an image anchor
    dfd.resolve new ImageAnchor @annotator, annotation, target, # Mandatory data
      0, 0, '', # Page numbers. If we want multi-page (=pdf) support, find that out
      image, selector.shapeType, selector.geometry, @annotorious

    dfd.promise()

  # This method is triggered by Annotorious to create image annotation
  annotate: (source, shape, geometry, tempID, annotoriousAnnotation) ->
    # Prepare a target describing selection

    # Prepare data for Annotator about the selection
    event =
      # This is the target
      targets: [
        source: @annotator.getHref()
        selector: [
          type: "ShapeSelector"
          source: source
          shapeType: shape
          geometry: geometry
        ]
      ]
      # This extra info will be merged into the annotation
      annotationData:
        temporaryImageID: tempID

    # Trigger the creation of a new annotation
    result = @annotator.onSuccessfulSelection event, true
    unless result
      @annotorious.deleteAnnotation annotoriousAnnotation

  # This method is triggered by Annotorious to show a list of annotations
  showAnnotations: (annotations) =>
    return unless annotations.length
    @annotator.onAnchorMousedown annotations, @highlightType
    @annotator.onAnchorClick annotations, @highlightType
