
root = exports ? this

# Help with the placement of nodes
RadialPlacement = () ->
  # stores the key -> location values
  values = d3.map()
  # how much to separate each location by
  increment = 40
  # how large to make the layout
  radius = 200
  # where the center of the layout should be
  center = {"x":0, "y":0}
  # what angle to start at
  start = -120
  current = start

  # Given an center point, angle, and radius length,
  # return a radial position for that angle
  radialLocation = (center, angle, radius) ->
    x = (center.x + radius * Math.cos(angle * Math.PI / 180))
    y = (center.y + radius * Math.sin(angle * Math.PI / 180))
    {"x":x,"y":y}

  # Main entry point for RadialPlacement
  # Returns location for a particular key,
  # creating a new location if necessary.
  placement = (key) ->
    value = values.get(key)
    if !values.has(key)
      value = place(key)
    value

  # Gets a new location for input key
  place = (key) ->
    value = radialLocation(center, current, radius)
    values.set(key,value)
    current += increment
    value

   # Given a set of keys, perform some 
  # magic to create a two ringed radial layout.
  # Expects radius, increment, and center to be set.
  # If there are a small number of keys, just make
  # one circle.
  setKeys = (keys) ->
    # start with an empty values
    values = d3.map()
  
    # number of keys to go in first circle
    firstCircleCount = 360 / increment

    # if we don't have enough keys, modify increment
    # so that they all fit in one circle
    if keys.length < firstCircleCount
      increment = 360 / keys.length

    # set locations for inner circle
    firstCircleKeys = keys.slice(0,firstCircleCount)
    firstCircleKeys.forEach (k) -> place(k)

    # set locations for outer circle
    secondCircleKeys = keys.slice(firstCircleCount)

    # setup outer circle
    radius = radius + radius / 1.8
    increment = 360 / secondCircleKeys.length

    secondCircleKeys.forEach (k) -> place(k)

  placement.keys = (_) ->
    if !arguments.length
      return d3.keys(values)
    setKeys(_)
    placement

  placement.center = (_) ->
    if !arguments.length
      return center
    center = _
    placement

  placement.radius = (_) ->
    if !arguments.length
      return radius
    radius = _
    placement

  placement.start = (_) ->
    if !arguments.length
      return start
    start = _
    current = start
    placement

  placement.increment = (_) ->
    if !arguments.length
      return increment
    increment = _
    placement

  return placement

Network = () ->
  # variables we want to access
  # in multiple places of Network
  width = 1200
  height = 1200
  # allData will store the unfiltered data
  allData = []
  curLinksData = []
  curNodesData = []
  linkedByIndex = {}
  # these will hold the svg groups for
  # accessing the nodes and links display
  nodesG = null
  linksG = null
  # these will point to the circles and lines
  # of the nodes and links
  node = null
  link = null
  # variables to refect the current settings
  # of the visualization
  layout = ""
  filter = "all"
  sort = ""
  # groupCenters will store our radial layout for
  # the group by shareFriend layout.
  groupCenters = null

  # our force directed layout
  force = d3.layout.force()
  # color function used to color nodes
  nodeColors = d3.scale.category20()
  # tooltip used to display details
  tooltip = Tooltip("vis-tooltip", 230)

  # charge used in shareFriend layout
  charge = (node) -> -Math.pow(node.radius, 2.0) / 2

  # Starting point for network visualization
  # Initializes visualization and starts force layout
  network = (selection, data) ->
    # format our data
    allData = setupData(data)

    # create our svg and groups
    vis = d3.select(selection).append("svg")
      .attr("width", width)
      .attr("height", height)
    linksG = vis.append("g").attr("id", "links")
    nodesG = vis.append("g").attr("id", "nodes")

    # setup the size of the force environment
    force.size([width, height])

    setLayout("force")
    setFilter("all")

    # perform rendering and start force layout
    update()

  # The update() function performs the bulk of the
  # work to setup our visualization based on the
  # current layout/sort/filter.
  #
  # update() is called everytime a parameter changes
  # and the network needs to be reset.
  update = () ->
    # filter data to show based on current filter settings.
    curNodesData = filterNodes(allData.nodes)
    curLinksData = filterLinks(allData.links, curNodesData)

    # sort nodes based on current sort and update centers for
    # radial layout
    if layout == "radial1"
      shareFriends = sortedshareFriends(curNodesData, curLinksData)
      updateCenters(shareFriends)

    # reset nodes in force layout
    force.nodes(curNodesData)

    # enter / exit for nodes
    updateNodes()

    # always show links in force layout
    if layout == "force"
      force.links(curLinksData)
      updateLinks()
    else
      # reset links so they do not interfere with
      # other layouts. updateLinks() will be called when
      # force is done animating.
      force.links([])
      # if present, remove them from svg 
      if link
        link.data([]).exit().remove()
        link = null

    # start me up!
    force.start()

  # Public function to switch between layouts
  network.toggleLayout = (newLayout) ->
    force.stop()
    setLayout(newLayout)
    update()

  # Public function to switch between filter options
  network.toggleFilter = (newFilter) ->
    force.stop()
    setFilter(newFilter)
    update()

  # Public function to switch between sort options
  network.toggleSort = (newSort) ->
    force.stop()
    setSort(newSort)
    update()

  network.updateData = (newData) ->
    allData = setupData(newData)
    link.remove()
    node.remove()
    update()
    
  # called once to clean up raw data and switch links to
  # point to node instances
  # Returns modified data
  setupData = (data) ->
    # initialize circle radius scale
    countExtent = d3.extent(data.nodes, (d) -> d.num_friends)
    circleRadius = d3.scale.sqrt().range([3, 10]).domain(countExtent)

    data.nodes.forEach (n) ->
      # set initial x/y to values within the width/height
      # of the visualization
      n.x = randomnumber=Math.floor(100+Math.random()*width/40)
      n.y = randomnumber=Math.floor(100+Math.random()*height/40)
      # add radius to the node so we can use it later
      n.radius = circleRadius(n.num_friends)

    # id's -> node objects
    nodesMap  = mapNodes(data.nodes)

    # switch links to point to node objects instead of id's
    data.links.forEach (l) ->
      l.source = nodesMap.get(l.source)
      l.target = nodesMap.get(l.target)

      # linkedByIndex is used for link sorting
      linkedByIndex["#{l.source.id},#{l.target.id}"] = 1

    data

  # Helper function to map node id's to node objects.
  # Returns d3.map of ids -> nodes
  mapNodes = (nodes) ->
    nodesMap = d3.map()
    nodes.forEach (n) ->
      nodesMap.set(n.id, n)
    nodesMap

  # Helper function that returns an associative array
  # with counts of unique attr in nodes
  # attr is value stored in node, like 'shareFriend'
  nodeCounts = (nodes, attr) ->
    counts = {}
    nodes.forEach (d) ->
      counts[d[attr]] ?= 0
      counts[d[attr]] += 1
    counts

  # Given two nodes a and b, returns true if
  # there is a link between them.
  # Uses linkedByIndex initialized in setupData
  neighboring = (a, b) ->
    linkedByIndex[a.id + "," + b.id] or
      linkedByIndex[b.id + "," + a.id]

  # Removes nodes from input array
  # based on current filter setting.
  # Returns array of nodes
  filterNodes = (allNodes) ->
    filteredNodes = allNodes
    num_friendss = allNodes.map((d) -> d.num_friends).sort(d3.ascending)
    if filter == "popular" or filter == "obscure"
      cutoff = d3.quantile(num_friendss, 0.8)
      filteredNodes = allNodes.filter (n) ->
        if filter == "popular"
          n.num_friends > cutoff
        else if filter == "obscure"
          n.num_friends <= cutoff
    if filter == 'hub'
        filteredNodes = allNodes.filter (n) ->
            n.num_friends > 100
    if filter == 'isolate'
        filteredNodes = allNodes.filter (n) ->
            n.num_friends < 20
    if filter == 'selectMajor'
        filteredNodes = allNodes.filter (n) ->
            n.major == "CS " or n.major == "Math "

    filteredNodes

  # Returns array of shareFriends/major sorted based on
  # current sorting method.
  sortedshareFriends = (nodes,links) ->
    shareFriends = []
    if sort == "major"
      counts = nodeCounts(nodes, "major")
      shareFriends = d3.entries(counts).sort (a,b) ->
        b.value - a.value
      shareFriends = shareFriends.map (v) -> v.key
    else
      # sort shareFriends
      counts = nodeCounts(nodes, "shareFriend")
      shareFriends = d3.entries(counts).sort (a,b) ->
        b.value - a.value
      shareFriends = shareFriends.map (v) -> v.key
    shareFriends

  updateCenters = (shareFriends) ->
    if layout == "radial1"
      groupCenters = RadialPlacement().center({"x":width/2, "y":height / 2 - 100})
        .radius(600).increment(40).keys(shareFriends)

  # Removes links from allLinks whose
  # source or target is not present in curNodes
  # Returns array of links
  filterLinks = (allLinks, curNodes) ->
    curNodes = mapNodes(curNodes)
    allLinks.filter (l) ->
      curNodes.get(l.source.id) and curNodes.get(l.target.id)

  # enter/exit display for nodes
  updateNodes = () ->
    node = nodesG.selectAll("circle.node")
      .data(curNodesData, (d) -> d.id)

    node.enter().append("circle")
      .attr("class", "node")
      .attr("cx", (d) -> d.x)
      .attr("cy", (d) -> d.y)
      .attr("r", (d) -> d.radius)
      .style("fill", (d) -> nodeColors(d.major))
      .style("stroke", (d) -> strokeFor(d))
      .style("stroke-width", 0.3)

    node.on("mouseover", showDetails)
      .on("mouseout", hideDetails)

    node.exit().remove()

  # enter/exit display for links
  updateLinks = () ->
    link = linksG.selectAll("line.link")
      .data(curLinksData, (d) -> "#{d.source.id}_#{d.target.id}")
    link.enter().append("line")
      .attr("class", "link")
      .attr("stroke", "#ddd")
      .attr("stroke-opacity", 1.0)
      .style("stroke-width", 0.3)
      .attr("x1", (d) -> d.source.x)
      .attr("y1", (d) -> d.source.y)
      .attr("x2", (d) -> d.target.x)
      .attr("y2", (d) -> d.target.y)

    link.exit().remove()

  # switches force to new layout parameters
  setLayout = (newLayout) ->
    layout = newLayout
    if layout == "force"
      force.on("tick", forceTick)
        .charge(-200)
        .linkDistance(150)
    else if layout == "radial1"
      force.on("tick", radialTick)
        .charge(charge)

  # switches filter option to new filter
  setFilter = (newFilter) ->
    filter = newFilter

  # switches sort option to new sort
  setSort = (newSort) ->
    sort = newSort

  # tick function for force directed layout
  forceTick = (e) ->
    node
      .attr("cx", (d) -> d.x)
      .attr("cy", (d) -> d.y)

    link
      .attr("x1", (d) -> d.source.x)
      .attr("y1", (d) -> d.source.y)
      .attr("x2", (d) -> d.target.x)
      .attr("y2", (d) -> d.target.y)

  # tick function for radial layout
  radialTick = (e) ->
    node.each(moveToRadialLayout(e.alpha))

    node
      .attr("cx", (d) -> d.x)
      .attr("cy", (d) -> d.y)

    if e.alpha < 0.03
      force.stop()
      updateLinks()

  # Adjusts x/y for each node to
  # push them towards appropriate location.
  # Uses alpha to dampen effect over time.
  moveToRadialLayout = (alpha) ->
    k = alpha * 0.1
    (d) ->
      if sort == 'major'
            centerNode = groupCenters(d.major)
            d.x += (centerNode.x - d.x) * k
            d.y += (centerNode.y - d.y) * k
      else
            centerNode = groupCenters(d.shareFriend)
            d.x += (centerNode.x - d.x) * k
            d.y += (centerNode.y - d.y) * k


  # Helper function that returns stroke color for
  # particular node.
  strokeFor = (d) ->
    d3.rgb(nodeColors(d.shareFriend)).darker().toString()

  # Mouseover tooltip function
  showDetails = (d,i) ->
    content = '<p class="main">' + d.name + '</span></p>'
    content += '<hr class="tooltip-hr">'
    content += '<p class="main">' + d.shareFriend + '</span></p>'
    content += '<p class="main">' + '# of common friends '+d.num_friends + '</span></p>'
    content += '<p class="main">' + 'Major '+d.major + '</span></p>'
    tooltip.showTooltip(content,d3.event)

    # higlight connected links
    if link
      link.attr("stroke", (l) ->
        if l.source == d or l.target == d then "#555" else "#ddd"
      )
        .attr("stroke-opacity", (l) ->
          if l.source == d or l.target == d then 1.0 else 0.5
        )

      # link.each (l) ->
      #   if l.source == d or l.target == d
      #     d3.select(this).attr("stroke", "#555")

    # highlight neighboring nodes
    # watch out - don't mess with node if search is currently matching
    node.style("stroke", (n) ->
      if (n.searched or neighboring(d, n)) then "#555" else strokeFor(n))
      .style("stroke-width", (n) ->
        if (n.searched or neighboring(d, n)) then 2.0 else 1.0)
  
    # highlight the node being moused over
    d3.select(this).style("stroke","black")
      .style("stroke-width", 2.0)

  # Mouseout function
  hideDetails = (d,i) ->
    tooltip.hideTooltip()
    # watch out - don't mess with node if search is currently matching
    node.style("stroke", (n) -> if !n.searched then strokeFor(n) else "#555")
      .style("stroke-width", (n) -> if !n.searched then 0.3 else 0.5)
    if link
      link.attr("stroke", "#ddd")
        .attr("stroke-opacity", 0.8)

  # Final act of Network() function is to return the inner 'network()' function.
  return network

# Activate selector button
activate = (group, link) ->
  d3.selectAll("##{group} a").classed("active", false)
  d3.select("##{group} ##{link}").classed("active", true)

$ ->
  myNetwork = Network()

  d3.selectAll("#layouts a").on "click", (d) ->
    newLayout = d3.select(this).attr("id")
    activate("layouts", newLayout)
    myNetwork.toggleLayout(newLayout)

  d3.selectAll("#filters a").on "click", (d) ->
    newFilter = d3.select(this).attr("id")
    activate("filters", newFilter)
    myNetwork.toggleFilter(newFilter)

  d3.selectAll("#sorts a").on "click", (d) ->
    newSort = d3.select(this).attr("id")
    activate("sorts", newSort)
    myNetwork.toggleSort(newSort)
        
  $("#song_select").on "change", (e) ->
    songFile = $(this).val()
    d3.json "data/#{songFile}", (json) ->
      myNetwork.updateData(json)
        
  d3.json "data/data0.json", (json) ->
    myNetwork("#vis", json)
