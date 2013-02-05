Charts = Charts or {}

# aboutInfographic
# ----------------

# Generates the his/hers timelines/infographics on the about page; input data
# is a list of objects with `city`, `year` (a float, indicating the moved-to
# date), `abbrCity` (for shorter labels), and `note` (displayed on hover).
Charts.aboutInfographic = ->
  # Defaults.
  width = 500
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
  iconPaths =
    his: 'M7.963,5.559C9.789,5.559,11,7.156,11,8.787v7.491c0.004,1.477-2.037,1.477-2.037,0V9.387H8.488 L6.744,28.483c0,2.022-2.463,2.022-2.463,0L2.537,9.387H2.052v6.892c0,1.465-2.052,1.465-2.052,0V8.742 c0-1.769,1.337-3.188,3.001-3.188L7.963,5.559z M5.494,4.871c1.306,0,2.363-1.091,2.363-2.436S6.8,0,5.494,0 C4.189,0,3.13,1.091,3.13,2.436S4.189,4.871,5.494,4.871z M5.494,2.436'
    hers: 'M4.535,2.438C4.535,1.091,5.646,0,7.016,0c1.371,0,2.482,1.091,2.482,2.438 c0,1.345-1.111,2.436-2.482,2.436C5.646,4.874,4.535,3.782,4.535,2.438z M7.016,2.438 M8.072,28.859l1.602-8.535h3.114L9.435,9.021 H10l1.953,6.434c0.465,1.47,2.419,0.845,1.984-0.662l-2.171-7.007c-0.268-0.789-1.302-2.218-3.068-2.218H6.927l0,0H5.283 c-1.783,0-2.814,1.417-3.046,2.218L0.066,14.8c-0.45,1.507,1.519,2.086,1.984,0.679l1.955-6.458h0.521L1.208,20.324h3.101 l1.603,8.524C5.912,30.382,8.072,30.382,8.072,28.859z'
  iconHeight = 30

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
      xEndcapEdge() - endcapWidth
    else
      xEndcapEdge() + endcapWidth
  xEndcapEdge = ->
    if alignLeft then width - xPadding() else xPadding()
  xPadding = ->
    if alignLeft then Math.ceil(padding / 2) else Math.floor(padding / 2)
  clipperId = (d, i) -> "clipper-#{idPrefix}#{i}"

  #### paddedStackLayout
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

  #### animate
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

  #### chart
  chart = (selection) -> selection.each (data) ->
    data = paddedStackLayout(data)
    extent = [data[0].y0, data[data.length - 1].y1]
    height = extent[1]
    labelAdj = labelAdjustments[if textWidth < 50 then 'small' else 'normal']

    defsEnter = selection.selectAll('defs')
        .data([1])
      .enter().append('defs')
    # Browsers disagree about what relative url references in external
    # stylesheets should be relative *to*. WebKit makes the pragmatic choice;
    # Firefox makes the pedantic one (quelle surprise):
    #   https://bugzilla.mozilla.org/show_bug.cgi?id=632004
    defsEnter.append('style')
        .text('.selected, .item.selected path.main { fill: url(#gradient); }')
    gradientEnter = defsEnter.append('linearGradient')
        .attr('id', 'gradient')
        .attr('x1', 0)
        .attr('y1', 0)
        .attr('x2', 0)
        .attr('y2', 1)
    gradientEnter.append('stop').classed('top', true)
        .attr('offset', '0%')
    gradientEnter.append('stop').classed('bottom', true)
        .attr('offset', '100%')

    g = selection
        .attr('width', width)
        .style('width', width)  # Chrome wouldn't reflow inline-block otherwise
        .attr('height', height + iconHeight + padding)
      .selectAll('g.items')
        .data([data])
    g.enter().append('g').classed('items', true)
    g.attr('transform', "translate(0, #{iconHeight + padding})")

    # Build the little his/hers icon.
    iconPath = selection.selectAll('path.icon')
        # Such a hack. May the gods have mercy on my soul.
        .data([if alignLeft then 'hers' else 'his'])
    iconPath
      .enter().append('path').classed('icon', true)
        .attr('d', (d) -> iconPaths[d])
        .attr('class', (d) -> 'icon ' + d)
        .attr('fill', fillColor)
        .attr('fill-opacity', .2)
    xIcon = if alignLeft then width - 15 else 1
    iconPath.attr('transform', "translate(#{xIcon}, 0)")

    items = g.selectAll('.item')
        .data(data, (d) -> d.year)

    # Each node is represented by a structure like this:
    #
    #     g.item
    #       g.triangle
    #         path.main
    #         path.endcap
    #       text

    itemsEnter = items
      .enter().append('g').classed('item', true)
        .attr('start', (d) -> d.year)  # used for ordering the cycler
    trianglesEnter = itemsEnter.append('g').classed('triangle', true)
    trianglesEnter.append('path').classed('main', true)
    trianglesEnter.append('path').classed('endcap', true)
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
          [xEndcapEdge(), invertY(d.y0)]
          [xEndcapEdge(), invertY(d.y1)]
          [xTriangleEdge(), invertY(d.y1)]
          [xPoint(), yLabel(i) - .5]
          [xLabel(), yLabel(i) - .5]
        ])
    items.select('path.endcap')
        .attr('fill', 'white')
        .attr('fill-opacity', '.15')
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


  #### Getter/setters

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

  # Make calls to the chart chainable.
  chart
