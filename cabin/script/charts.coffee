Charts = Charts or {}

Charts.aboutInfographic = ->
  # Defaults.
  width = 500
  height = undefined  # computed based on data

  endcapWidth = 10
  xLabel = 0
  xPoint = 100
  xFull = width

  fillColor = 'black'
  fontSize = 10
  textOffsets =
    normal: {padding: 6, adjust: '-.5em'}
    small: {padding: 2, adjust: '-.28em'}
  pixelsPerYear = 8
  padding = 5

  # Since clip paths require IDs, we need to avoid duplicate IDs.
  idPrefix = ''
  firstRender = true

  line = d3.svg.line()

  # Implemented as functions since the values are computed from changeable
  # settings.
  leftAligned = -> xFull > xPoint
  xTriangleEdge = ->
    if leftAligned()
      xFull - endcapWidth
    else
      xFull + endcapWidth
  clipperId = (d, i) -> "clipper-#{idPrefix}#{i}"

  # A helper for converting a simple {key: <float year>, value: <label>} list
  # into a list of objects with label, y0, and y1. (Because there is padding
  # between each item in the stack, a linear scale won't work.)
  paddedStackLayout = (data) ->
    # Separate key/values into pairs and sort.
    sorted = data
      .map((d) -> d.key = parseFloat(d.key); d)
      .sort((a, b) -> d3.ascending(a.key, b.key))
    yearZero = sorted[0].key
    now = new Date
    now = now.getFullYear() + (now.getMonth() / 12)
    # Each item knows its start date, but the end date must be fetched from the
    # following item in the list.
    sorted.map (d, i) ->
      start = d.key
      end = sorted[i + 1]?.key or now
      itemHeight = (end - start) * pixelsPerYear
      bottomRight = (start - yearZero) * pixelsPerYear + i * padding
      datum =
        key: d.key
        label: d.value
        y0: bottomRight
        y1: bottomRight + itemHeight

  # Build clip paths for animation.
  animate = (selection, data, invertY, yLabel) ->
    clipPaths = selection.selectAll('clipPath')
        .data(data)
      .enter().append('clipPath')
        .attr('id', clipperId)
        .append('rect')

    clipDuration = d3.scale.linear()
        .domain([0, data.length])
        .range([700, 500])
    clipDelay = d3.scale.linear()
        .domain([0, data.length])
        .range([0, 750])
    clipPaths
        .attr('x', xLabel)
        .attr('y', (d) -> invertY(d.y1))
        .attr('width', if leftAligned() then 0 else width)
        .attr('height', (d, i) -> yLabel(i) - invertY(d.y1))
      .transition()
        .duration((d, i) -> clipDuration(i))
        .delay((d, i) -> clipDelay(i))
        .attr((if leftAligned() then 'width' else 'x'), xFull)
        .each 'end.transition', ->
          # Remove clipPath element after transition; Safari would show
          # artifacts when using the inspector otherwise.
          p = @parentNode
          p.parentNode.removeChild(p)

  # Build the chart.
  chart = (selection) -> selection.each (data) ->
    data = paddedStackLayout(data)
    extent = [data[0].y0, data[data.length - 1].y1]
    height = extent[1]
    textOffset = (->
      textWidth = Math.abs(xPoint - xLabel)
      textOffsets[if textWidth < 50 then 'small' else 'normal'])()

    items = selection
        .attr('width', width)
        .attr('height', height)
      .selectAll('.item')
        .data(data, (d) -> d.key)

    # Each node is represented by a structure like this:
    #   g.item
    #     g.triangle
    #       path.main
    #       path.highlight
    #     text
    itemsEnter = items
      .enter().append('g').classed('item', true)
    trianglesEnter = itemsEnter.append('g').classed('triangle', true)
    trianglesEnter.append('path').classed('main', true)
    trianglesEnter.append('path').classed('highlight', true)
    itemsEnter.append('text')

    items.exit().remove()

    invertY = d3.scale.linear()
        .domain(extent)
        .range(extent.reverse())
    yLabel = d3.scale.linear()
        .domain([0, data.length])
        .rangeRound(
          [height, height - (fontSize + textOffset.padding) * data.length])
    opacityScale = d3.scale.linear()
        .domain([data.length, 0])
        .range([1, .1])

    if firstRender
      firstRender = false
      animate(selection, data, invertY, yLabel)

    # Build triangle and endcap.
    items.select('g.triangle')
        .attr('fill-opacity', (d, i) -> opacityScale(i))
        .attr('clip-path', (d, i) -> "url(##{clipperId(d, i)})")
    # TODO: could do all this in one path by getting fancy with gradients
    items.select('path.main')
        .attr('fill', fillColor)
        .attr 'd', (d, i) -> line([
          [xLabel, yLabel(i)]
          [xPoint, yLabel(i)]
          [xTriangleEdge(), invertY(d.y0)]
          [xTriangleEdge(), invertY(d.y1)]
          [xPoint, yLabel(i) - .5]
          [xLabel, yLabel(i) - .5]
        ])
    items.select('path.highlight')
        .attr('fill', d3.rgb(fillColor).brighter(1))
        .attr 'd', (d, i) -> line([
          [xTriangleEdge(), invertY(d.y0)]
          [xFull, invertY(d.y0)]
          [xFull, invertY(d.y1)]
          [xTriangleEdge(), invertY(d.y1)]
        ])

    # Build labels.
    text = items.select('text')
      .text((d) -> d.label)
      .attr('x', xLabel)
      .attr('y', (d, i) -> yLabel(i))
      .attr('dy', textOffset.adjust)
      .attr('font-size', fontSize)
      .attr('fill', fillColor)
    # Align text right if the graph is flipped.
    if !leftAligned()
      text.attr('text-anchor', 'end')


  ## Getter/setters  #########################################################

  chart.width = (_) ->
    return width unless arguments.length
    width = _
    chart

  chart.xLabel = (_) ->
    return xLabel unless arguments.length
    xLabel = _
    chart

  chart.xPoint = (_) ->
    return xPoint unless arguments.length
    xPoint = _
    chart

  chart.xFull = (_) ->
    return xFull unless arguments.length
    xFull = _
    chart

  chart.pixelsPerYear = (_) ->
    return pixelsPerYear unless arguments.length
    pixelsPerYear = _
    chart

  chart.padding = (_) ->
    return padding unless arguments.length
    padding = _
    chart

  chart.fillColor = (_) ->
    return fillColor unless arguments.length
    fillColor = _
    chart

  chart.idPrefix = (_) ->
    return idPrefix unless arguments.length
    idPrefix = _
    chart

  chart  # chainable
