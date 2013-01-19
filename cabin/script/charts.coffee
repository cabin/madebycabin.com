Charts = Charts or {}

Charts.aboutInfographic = ->
  # Defaults.
  width = 500
  height = undefined  # computed based on data
  alignLeft = true
  textWidth = 100
  endcapWidth = 10
  fillColor = '#2b2b2b'
  fontSize = 10
  labelAdjustments =
    normal: {padding: 6, adjust: '-.5em', attr: 'city'}
    small: {padding: 2, adjust: '-.28em', attr: 'abbrCity'}
  pixelsPerYear = 8
  padding = 5

  # Since clip paths require IDs, we need to avoid duplicate IDs.
  idPrefix = ''
  firstRender = true

  line = d3.svg.line()

  # Implemented as functions since the value is computed from changeable
  # settings.
  xLabel = ->
    if alignLeft then 0 else width
  xPoint = ->
    if alignLeft then textWidth else width - textWidth
  xTriangleEdge = ->
    if alignLeft
      width - endcapWidth
    else
      xEndcapEdge() + endcapWidth
  xEndcapEdge = ->
    if alignLeft then width else padding
  clipperId = (d, i) -> "clipper-#{idPrefix}#{i}"

  # A helper for decorating a list of objects with y0 and y1 based on year.
  # (Because there is padding between each item in the stack, a linear scale
  # won't work.)
  paddedStackLayout = (data) ->
    data = data.sort((a, b) -> d3.ascending(a.year, b.year))
    yearZero = data[0].year
    now = new Date
    now = now.getFullYear() + (now.getMonth() / 12)
    # Each item knows its start date, but the end date must be fetched from the
    # following item in the list.
    data.map (item, i) ->
      start = item.year
      end = data[i + 1]?.year or now
      itemHeight = (end - start) * pixelsPerYear
      bottomRight = (start - yearZero) * pixelsPerYear + i * padding
      item.y0 = bottomRight
      item.y1 = bottomRight + itemHeight
      item.yearEnd = end
      item

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
        .attr('x', xLabel())
        .attr('y', (d) -> invertY(d.y1))
        .attr('width', if alignLeft then 0 else width)
        .attr('height', (d, i) -> yLabel(i) - invertY(d.y1))
      .transition()
        .duration((d, i) -> clipDuration(i))
        .delay((d, i) -> clipDelay(i))
        .attr((if alignLeft then 'width' else 'x'), xEndcapEdge())
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
    labelAdj = labelAdjustments[if textWidth < 50 then 'small' else 'normal']

    items = selection
        .attr('width', width)
        .style('width', width)  # Chrome wouldn't reflow inline-block otherwise
        .attr('height', height)
      .selectAll('.item')
        .data(data, (d) -> d.year)

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
          [height, height - (fontSize + labelAdj.padding) * data.length])
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
          [xLabel(), yLabel(i)]
          [xPoint(), yLabel(i)]
          [xTriangleEdge(), invertY(d.y0)]
          [xTriangleEdge(), invertY(d.y1)]
          [xPoint(), yLabel(i) - .5]
          [xLabel(), yLabel(i) - .5]
        ])
    items.select('path.highlight')
        .attr('fill', d3.rgb(fillColor).brighter(1))
        .attr 'd', (d, i) -> line([
          [xTriangleEdge(), invertY(d.y0)]
          [xEndcapEdge(), invertY(d.y0)]
          [xEndcapEdge(), invertY(d.y1)]
          [xTriangleEdge(), invertY(d.y1)]
        ])

    # Build labels.
    text = items.select('text')
      .text((d) -> d[labelAdj.attr])
      .attr('x', xLabel())
      .attr('y', (d, i) -> yLabel(i))
      .attr('dy', labelAdj.adjust)
      .attr('font-size', fontSize)
      .attr('fill', fillColor)
    # Align text right if the graph is flipped.
    if not alignLeft
      text.attr('text-anchor', 'end')


  ## Getter/setters  #########################################################

  chart.width = (_) ->
    return width unless arguments.length
    width = _
    chart

  chart.textWidth = (_) ->
    return textWidth unless arguments.length
    textWidth = _
    chart

  chart.alignLeft = (_) ->
    return alignLeft unless arguments.length
    alignLeft = _
    chart

  chart.idPrefix = (_) ->
    return idPrefix unless arguments.length
    idPrefix = _
    chart

  chart.fillColor = (_) ->
    return fillColor unless arguments.length
    fillColor = _
    chart

  chart.padding = (_) ->
    return padding unless arguments.length
    padding = _
    chart

  chart.pixelsPerYear = (_) ->
    return pixelsPerYear unless arguments.length
    pixelsPerYear = _
    chart

  chart  # chainable
