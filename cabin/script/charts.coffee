Charts = Charts or {}

# aboutInfographic
# ----------------

# Generates the his/hers timelines/infographics on the about page; input data
# is a list of objects with `city`, `year` (a float, indicating the moved-to
# date), `abbrCity` (for shorter labels), and `note` (displayed on hover).
Charts.aboutInfographic = ->
  opts =
    width: 500
    height: 350
    rightColumn: -> Math.ceil(opts.width / 2)
    textWidth: 100
    endcapWidth: 10
    padding: 5
    fill: '#2b2b2b'
    selectedFill: ['#2b2b2b', '#000']
    label: {size: 12, padding: 6, adjust: '-.5em', attr: 'label'}
    leftIcon: 'M4.535,2.438C4.535,1.091,5.646,0,7.016,0c1.371,0,2.482,1.091,2.482,2.438 c0,1.345-1.111,2.436-2.482,2.436C5.646,4.874,4.535,3.782,4.535,2.438z M7.016,2.438 M8.072,28.859l1.602-8.535h3.114L9.435,9.021 H10l1.953,6.434c0.465,1.47,2.419,0.845,1.984-0.662l-2.171-7.007c-0.268-0.789-1.302-2.218-3.068-2.218H6.927l0,0H5.283 c-1.783,0-2.814,1.417-3.046,2.218L0.066,14.8c-0.45,1.507,1.519,2.086,1.984,0.679l1.955-6.458h0.521L1.208,20.324h3.101 l1.603,8.524C5.912,30.382,8.072,30.382,8.072,28.859z'
    rightIcon: 'M7.963,5.559C9.789,5.559,11,7.156,11,8.787v7.491c0.004,1.477-2.037,1.477-2.037,0V9.387H8.488 L6.744,28.483c0,2.022-2.463,2.022-2.463,0L2.537,9.387H2.052v6.892c0,1.465-2.052,1.465-2.052,0V8.742 c0-1.769,1.337-3.188,3.001-3.188L7.963,5.559z M5.494,4.871c1.306,0,2.363-1.091,2.363-2.436S6.8,0,5.494,0 C4.189,0,3.13,1.091,3.13,2.436S4.189,4.871,5.494,4.871z M5.494,2.436'

  chartHeight = pixelsPerYear = null  # computed later
  line = d3.svg.line()
  yLabel = d3.scale.linear()
  opacityScale = d3.scale.linear().range([.9, .1])
  animateDuration = d3.scale.linear().range([500, 700])
  animateDelay = d3.scale.linear().range([750, 0])

  # Each chart is composed of two chunks, one on the left and one on the right.
  # This method makes it simpler to decide left vs. right based on data index.
  lr = (i) -> if i is 0 then 'left' else 'right'


  #### chart
  # Construct the complete chart, mostly using the helpers below.
  chart = (g) -> g.each (data) ->
    throw Error('expected two elements of data') unless data.length is 2
    g = d3.select(this)
        .attr('width', opts.width)
        .attr('height', opts.height)
    buildDefs(g)
    iconHeight = buildIcons(g)

    # Compute globals that are based on data and/or variable options.
    chartHeight = opts.height - (iconHeight + opts.padding)
    pixelsPerYear = findPixelsPerYear(data)

    # Build the charts.
    charts = g.selectAll('g.chart').data(paddedStackLayout(data))
    charts.enter().append('g')
        .attr('class', (d, i) -> 'chart ' + lr(i))
    charts.attr('transform', "translate(0, #{iconHeight + opts.padding})")
    buildChart(charts.filter('.left'), 0)
    buildChart(charts.filter('.right'), 1)


  #### buildDefs
  # Construct the `defs` element, necessary for styles and gradients.
  buildDefs = (g) ->
    defs = g.selectAll('defs')
        .data([true])
    defsEnter = defs.enter().append('defs')

    # Define a top-down linear gradient for the selection color.
    defsEnter.append('linearGradient')
        .attr('id', 'selected-fill')
        .attr('x1', 0).attr('y1', 0)
        .attr('x2', 0).attr('y2', 1)
    stopOffset = d3.scale.linear()
        .domain([0, opts.selectedFill.length - 1])
    stops = defs.select('#selected-fill').selectAll('stop')
        .data(opts.selectedFill)
    stops.enter().append('stop')
    stops.exit().remove()
    stops
        .attr('offset', (d, i) -> stopOffset(i))
        .attr('stop-color', (d) -> d)

    # Browsers disagree about what relative url references in external
    # stylesheets should be relative *to*. WebKit makes the pragmatic choice;
    # Firefox makes the pedantic one (quelle surprise):
    #   https://bugzilla.mozilla.org/show_bug.cgi?id=632004
    defsEnter.append('style')
        .text('.selected, .item.selected path.main { fill: url(#selected-fill); }')


  #### buildIcons
  # Construct paths for the icons at the top of the chart. Returns the height
  # of the tallest icon.
  buildIcons = (g) ->
    paths = g.selectAll('path.icon')
        .data([opts.leftIcon, opts.rightIcon])
    paths.enter().append('path')
        .classed('icon', true)
        .attr('id', (d, i) -> "#{lr(i)}-icon")
        .attr('fill-opacity', 0.2)
    paths
        .attr('d', (d) -> d)
        .attr('fill', opts.fill)
        # Center the icon over its endcap.
        .attr 'transform', (d, i) ->
          x = xPositions(i)
          endcapCenter = (x.endcap + x.edge) / 2
          iconWidth = @getBoundingClientRect().width
          "translate(#{endcapCenter - iconWidth / 2}, 0)"
    # Return the height of the tallest icon.
    Math.ceil(d3.max(paths[0], (node) -> node.getBoundingClientRect().height))


  #### findPixelsPerYear
  # Based on the given height and data, compute how many pixels should
  # represent a year.
  findPixelsPerYear = (data) ->
    now = new Date
    now = now.getFullYear() + (now.getMonth() / 12)
    ppy = (columnData) ->
      range = now - d3.min(columnData, (d) -> d.year)
      availableHeight = chartHeight - (columnData.length - 1) * opts.padding
      availableHeight / range
    Math.min(ppy(data[0]), ppy(data[1]))


  #### buildChart
  # Construct elements for each item of a single chart column.
  #
  #     g.chart ... (one per column)
  #       g.item ... (one per datum)
  #         g.triangle
  #           path.main
  #           path.endcap
  #         text
  #         clipPath (for animation)
  #
  buildChart = (g, i) ->
    # Create our item node trees.
    items = g.selectAll('g.item').data((d) -> d)
    itemsEnter = items.enter().append('g').classed('item', true)
    trianglesEnter = itemsEnter.append('g').classed('triangle', true)
    trianglesEnter.append('path').classed('main', true)
    trianglesEnter.append('path').classed('endcap', true)
    itemsEnter.append('text')

    # In the unlikely event of reduced data, just remove extra items.
    items.exit().remove()

    # Adjust scales.
    data = items.data()
    lastIndex = data.length - 1
    labelHeight = opts.label.size + opts.label.padding
    yLabel.domain([lastIndex, lastIndex - 1])
        .rangeRound([data[lastIndex].y1, data[lastIndex].y1 - labelHeight])
    opacityScale.domain([0, lastIndex])
    animateDuration.domain([0, data.length])
    animateDelay.domain([0, data.length])
    x = xPositions(i)

    # Animate new items in by applying a clipPath to g.triangle that
    # transitions from the edge of the graph to full-size. For the left column,
    # animate width; for the right column, start width at the full width of the
    # column, then animate `x` leftwards.
    itemsEnter.append('clipPath')
        .attr('id', (d, j) -> "clip-#{i}-#{j}")
      .append('rect')
        .attr('x', x.text)
        .attr('y', 0)
        .attr('width', x.clipWidth)
        .attr('height', chartHeight)
      .transition()
        .duration((d, i) -> animateDuration(i))
        .delay((d, i) -> animateDelay(i))
        .attr(x.animateAttr, x.edge)

    # Configure shapes.
    items
        .attr('start', (d) -> d.year)  # used for ordering the cycler
      .select('g.triangle')
        .attr('fill-opacity', (d, i) -> opacityScale(i))
        .attr('clip-path', (d, j) -> "url(#clip-#{i}-#{j})")
    items.select('path.main')
        .attr('fill', opts.fill)
        .attr('d', trianglePath(x))
    items.select('path.endcap')
        .attr('fill', 'white')
        .attr('fill-opacity', '.15')
        .attr('d', endcapPath(x))

    # Build labels.
    text = items.select('text')
      .text((d) -> d[opts.label.attr])
      .attr('x', x.text)
      .attr('y', (d, i) -> yLabel(i))
      .attr('dy', opts.label.adjust)
      .attr('font-size', opts.label.size)
      .attr('fill', opts.fill)
    if lr(i) is 'right'
      text.attr('text-anchor', 'end')

  trianglePath = (x) ->
    (d, i) ->
      line([
        [x.text, yLabel(i)]
        [x.point, yLabel(i)]
        [x.endcap, Math.round(d.y1)]
        [x.edge, Math.round(d.y1)]
        [x.edge, Math.round(d.y0)]
        [x.endcap, Math.round(d.y0)]
        [x.point, yLabel(i) - .5]
        [x.text, yLabel(i) - .5]
      ])

  endcapPath = (x) ->
    (d, i) ->
      line([
        [x.endcap, Math.round(d.y0)]
        [x.edge, Math.round(d.y0)]
        [x.edge, Math.round(d.y1)]
        [x.endcap, Math.round(d.y1)]
      ])


  #### xPositions
  # Computes the `x` coordinate for each necessary point in the graph, using
  # the data's index (i.e., column) for orientation.
  xPositions = (i) ->
    if lr(i) is 'left'
      text: 0
      point: opts.textWidth
      endcap: opts.rightColumn() - opts.padding - opts.endcapWidth
      edge: opts.rightColumn() - opts.padding
      animateAttr: 'width'
      clipWidth: 0
    else
      text: opts.width
      point: opts.width - opts.textWidth
      endcap: opts.rightColumn() + opts.endcapWidth
      edge: opts.rightColumn()
      animateAttr: 'x'
      clipWidth: opts.width - opts.rightColumn()


  #### paddedStackLayout
  # A helper for decorating a list of objects with y0 and y1 based on year.
  # (Because there is padding between each item in the stack, a linear scale
  # won't work.) Depends on a precomputed global `pixelsPerYear`.
  paddedStackLayout = (data) ->
    invertY = d3.scale.linear()
      .range([0, chartHeight])
      .domain([chartHeight, 0])
    now = new Date
    now = now.getFullYear() + (now.getMonth() / 12)
    data.map (d, i) ->
      d.sort((a, b) -> d3.descending(a.year, b.year)).map (item, i) ->
        lastItem = d[i - 1] or null
        start = item.year
        end = lastItem?.year or now
        height = (end - start) * pixelsPerYear
        item.y0 = if lastItem? then lastItem.y1 + opts.padding else 0
        item.y1 = item.y0 + height
        item.yearEnd = end
        item


  #### External interface
  # Provide chainable getters/setters for all `opts`, and return `chart`.
  getset = (attr) -> (value) ->
    return opts[attr] unless arguments.length
    opts[attr] = value
    chart
  for own k of opts
    chart[k] = getset(k)

  chart
