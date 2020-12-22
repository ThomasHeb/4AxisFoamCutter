#to_a wandelt in ein array um


@@version = 'v0.0.1'

require 'sketchup'
require 'io/console'                                                                                                       
 
@configKeys = [\
               #"cutDiamiter",\
               "decimalPlaces",\
               "units",\
               "labelXAxis",\
               "labelYAxis",\
               "labelUAxis",\
               "labelZAxis",\
               "feedSpeed",\
               "hotwire"] 
@config = {}

# Load configuration from persistent storage into @config hashmap.
def loadConfig()
  defaultValue = {\
                  #"cutDiamiter" => "0.10",\
                  "decimalPlaces" => "3",\
                  "units" => "mm",\
                  "labelXAxis" => "X",\
                  "labelYAxis" => "Y",\
                  "labelUAxis" => "U",\
                  "labelZAxis" => "Z",\
                  "feedSpeed" => "100",\
                  "hotwire" => "90"}

  @configKeys.each do | key |
    value = Sketchup.read_default('dla_foam_cutter_rb', key)
    puts("load: #{key}, #{value}")
    if value == nil
      value = defaultValue[key]
    end
    @config[key] = value
  end
end

# Reset config to default values.
def clearConfig()
  @config.each do |key, value|
    result = Sketchup.write_default('dla_foam_cutter_rb', key,  nil)
    puts("clear: #{key} #{result}")
  end
end

# Save entries in @config to persistent storage.
def saveConfig()
  @config.each do |key, value|
    result = Sketchup.write_default('dla_foam_cutter_rb', key,  value)
    puts("save: #{key}, #{value}, #{result}")
  end
end

 

# Set values in the @config hashmap.
def menu()
  configDescriptions = {\
                        #"cutDiamiter" => "Durchmesser Hotwire (mm)",\
                        "decimalPlaces" => "Digits for GCode",\
                        "units" => "Units for GCode",\
                        "labelXAxis" => "Left Horizontal",\
                        "labelYAxis" => "Left Vertical",\
                        "labelUAxis" => "Right Horizontal",\
                        "labelZAxis" => "Right Vertical",\
                        "feedSpeed" => "Feed Speed mm/min",\
                        "hotwire" => "Hotwire power %"}
  #sizes = "0.00|"\
  #        "0.01|0.02|0.03|0.04|0.05|0.06|0.07|0.08|0.09|0.10|"\
  #        "0.11|0.12|0.13|0.14|0.15|0.16|0.17|0.18|0.19|0.20|"\
  #        "0.21|0.22|0.23|0.24|0.25|0.26|0.27|0.28|0.29|0.30|"\
  #        "0.31|0.32|0.33|0.34|0.35|0.36|0.37|0.38|0.39|0.40|"\
  #        "0.41|0.42|0.43|0.44|0.45|0.46|0.47|0.48|0.49|0.50"
  menuOptions = {\
                 #"cutDiamiter" => sizes,\
                 "decimalPlaces" => "0|1|2|3|4",\
                 "units" => "mm|inch",\
                 "labelXAxis" => "X|Y|Z|U|W|A",\
                 "labelYAxis" => "X|Y|Z|U|W|A",\
                 "labelUAxis" => "X|Y|Z|U|W|A",\
                 "labelZAxis" => "X|Y|Z|U|W|A",\
                 "feedSpeed" => "50|100|150|200|250|300|350|400|450|500|550|600|650|700|750|800|850|900|950|1000",\
                 "hotwire" => "10|20|30|40|50|60|70|80|90|100"}
         
  descriptions = []
  values = []
  options = []
  
  @configKeys.each do | key |
    descriptions.push(configDescriptions[key])
    values.push(@config[key])
    options.push(menuOptions[key])
  end
 
  input = UI.inputbox descriptions, values, options, "Gcode options."

  if input
    for x in 0..(input.size - 1)
      key = @configKeys[x]
      @config[key] = input[x]
      puts("menu: #{key} #{input[x]}")
    end
    return true
  end
end 


# Round floats down to a sane number of decimal places.
def roundToPlaces(value, places, units)
  if units == "mm"
    value = value.to_mm
  end
  places = places.to_i
  #puts("places #{places}")
  returnVal = value.round(places)
  return returnVal
end

# Add a menu for Settings
if (not $fcSettingsLoaded)
  puts("Load Settings menu")
  UI.menu("Plugins").add_item("FoamCutter Settings") {
    loadConfig()
    if menu()
      saveConfig()
    end
  }
  $fcSettingsLoaded = true
end



# Add a menu for Settings
if (not $fcImportLoaded)
  puts("Load Import menu")
  UI.menu("Plugins").add_item("FoamCutter Import how-File") {
    loadConfig()
    importHOW(@config["units"])
  }
  $fcImportLoaded = true
end

class String
  def isFloat?
    Float(self) != nil rescue false
  end
end

def importHOW(units)
  filename = UI.openpanel("Open HOW File", "c:/", "HOW Files|*.how||")
  if filename
    file = File.open(filename)
    lines = file.readlines
    lineCount = lines.size
    
    xValues = []
    yValues = []
    uValues = []
    zValues = []
    
    # read line by line
    lines.each do |line|
      # split the line in segments
      valid = false
      seg = line.split()
      seg.each_with_index do |s, index|
        if index == 0
          if s.isFloat? 
            valid = true
          end
        end
        if valid
          if index < 4
            value = s.to_f
            if units == "mm"
              value = value.mm
            end
            if index == 0
              xValues.push(value)
            end
            if index == 1
              yValues.push(value)
            end
            if index == 2
              uValues.push(value)
            end
            if index == 3
              zValues.push(value)
            end
            
          end
          
        end
      end
    end
    
    nValues = xValues.size
  
    if nValues > 0
      model = Sketchup.active_model
      entities = model.active_entities
  
      point1 = Geom::Point3d.new(0,xValues[0],yValues[0])
      i = 1
      while i < nValues
        point2 = Geom::Point3d.new(0,xValues[i],yValues[i])
        entities.add_line point1,point2
        point1 = point2
        i += 1
      end
      
      point1 = Geom::Point3d.new(50.mm,uValues[0],zValues[0])
      i = 1
      while i < nValues
        point2 = Geom::Point3d.new(50.mm,uValues[i],zValues[i])
        entities.add_line point1,point2
        point1 = point2
        i += 1
      end
    end
  end
  return true
end 


# Add a menu for Tool
if (not $fcToolLoaded)
  puts("Load Tool menu")
  UI.menu("Plugins").add_item("FoamCutter Tool") {
    loadConfig()
    cutter = FCutter.new
    cutter.labelX = @config["labelXAxis"]
    cutter.labelY = @config["labelYAxis"]
    cutter.labelU = @config["labelUAxis"]
    cutter.labelZ = @config["labelZAxis"]
    cutter.places = @config["decimalPlaces"]
    cutter.units = @config["units"]
    Sketchup.active_model.select_tool cutter
  }
  $fcToolLoaded = true
end


class FCutter
  @@dx = 1.feet
  @@dy = 1.feet
  
  @leftPoints = {}
  @rightPoints = {}
  def labelX=(z)
    @labelX = z
  end
  def labelX
    @labelX
  end
  def labelY=(z)
    @labelY = z
  end
  def labelY
    @labelY
  end
  def labelU=(z)
    @labelU = z
  end
  def labelU
    @labelU
  end
  def labelZ=(z)
    @labelZ = z
  end
  def labelZ
    @labelZ
  end
  def places=(z)
    @places = z
  end
  def places
    @places
  end
  def units=(z)
    @units = z
  end
  def units
    @units
  end
  
  # 1. automatically called
  def initialize
      puts("initialize")
      # global storage for two click points
      @ip1 = Sketchup::InputPoint.new
      @ip2 = Sketchup::InputPoint.new
      reset()
  end

  # 2. reset the tool
  def reset
      puts("reset")
      # reset statemachine and click points
      @state = 0
      @ip1.clear
      @ip2.clear
      @drawn = false
      # wait for left button down event
      @shift_down_time = Time.now
      Sketchup::set_status_text "Select first path"
      
  end
  

  def activate
      puts("activate")
      self.reset
      @drawn = false
  end

  def deactivate(view)
    puts("deactivate")
    view.invalidate
  end

  # 3 + 4 left button down event
  def onLButtonDown(flags, x, y, view)
      puts("onLButtonDown")
      self.setSelectedPath(x, y, view)
      #self.increment_state
      view.lock_inference
  end

  def onLButtonUp(flags, x, y, view)
      puts("onLButtonUp")
  end
  
 
  def onCancel(flag, view)
     puts("onCancel")
     reset()
     Sketchup.active_model.select_tool nil
  end
  
  # 3a + 4a statemachine
  def setSelectedPath(x, y, view)
    puts("setSelectedPath")
    #if( !@ip1.pick(view, x, y, @ip2) )
    #    return false
    #end
    
    if (@state == 0)
        @ip1 = view.inputpoint x, y
        e = @ip1.edge
        if (e == nil)
          return false
        end
        puts("edge selected")
        
        Sketchup::set_status_text "Select second path"
        @state = 1
        return true
    end
    if (@state == 1)
        @ip2 = view.inputpoint x, y
        e = @ip2.edge
        if (e == nil)
          return false
        end
          
        
        generateGCode()
        
        Sketchup.active_model.select_tool nil
        return true
    end
  end

  def generateGCode()
    if (@ip1.edge == nil || @ip2.edge == nil)
      UI.messagebox('unable to generate path, no edge selected')
      return false
    end
    
     
    @leftPoints     = []
    @rightPoints    = []
    # generate the pathes
    @leftPoints     = getPathFrom(@ip1.edge)
    @rightPoints    = getPathFrom(@ip2.edge)
    
    file = UI.savepanel "GCode File", "c:\\", "default.nc"
    if file
      if @leftPoints.count != @rightPoints.count
        UI.messagebox('the number of points in the two paths are not equal')
      end
      
   
      if @leftPoints.count > @rightPoints.count
        length = @leftPoints.count
      else 
        length = @rightPoints.count
      end
      
      i = 0
      x = 0
      y = 0
      u = 0
      z = 0
      
      puts("places: #{places}")
      puts("units: #{units}")
      
      
      outputfile = File.new( file , "w" )
	  while i < length
         if i < @leftPoints.count
           x = roundToPlaces(@leftPoints[i].position.y, places, units)
           y = roundToPlaces(@leftPoints[i].position.z, places, units)
         end
         if i < @rightPoints.count
           u = roundToPlaces(@rightPoints[i].position.y, places, units)
           z = roundToPlaces(@rightPoints[i].position.z, places, units)
         end
         puts("G90#{labelX}#{x}#{labelY}#{y}#{labelU}#{u}#{labelZ}#{z}")
         outputfile.puts("G90#{labelX}#{x}#{labelY}#{y}#{labelU}#{u}#{labelZ}#{z}")
         i += 1
      end
      outputfile.close
      #@outputfile.puts("G00 X#{@pos_x} Y#{@pos_y} ")
      UI.messagebox('Ready')
      
    
    
    else
      UI.messagebox('Unable to generate file')
      return false
    end
 
  end
  
  def getPathFrom(edge) 
    
    currentPoint  = Sketchup::Vertex.new
    nextPoint     = Sketchup::Vertex.new
    edges         = []
    path          = []
    
    # ermittle alle verbundenen edges
    entities = edge.all_connected
    entities.each do |e|
      if (e.is_a? Sketchup::Edge)
        edges.push(e)
      end
    end
     
    # ermittle welcher der startpunkt ist
    currentPoint  = firstPoint(edges, edge.start, edge.end)
    # übernehme den ersten Punkt
    path.push(currentPoint)
    # ermittle den zweiten punkt
    nextPoint     = edge.other_vertex currentPoint
     
    while nextPoint != nil
      path.push(nextPoint)
      # ermittle die verbleibenden Kannten
      edges = edgesToGo(edges, currentPoint, nextPoint)
      # einen punkt weiterschalten
      currentPoint = nextPoint
      # nächsten Punkt ermitteln
      nextPoint = nextPoint(edges, currentPoint)
    end
   
    return path
  end
  
  
  def firstPoint(edges, p1, p2) 
      used = 0 
      edges.each do |e|
        if (e.used_by? p1)
          used += 1
        end
      end
      if used == 2
        return p2
      else
        return p1
      end
  end
  
  def upperPoint(p1, p2) 
    if (p1.position.z > p2.position.z)
      return p1
    elsif (p1.position.z < p2.position.z) 
      return p2
    elsif (p1.position.y < p2.position.y)
      return p1
    else  
      return p2
    end
  end
  
  def edgesToGo(edges, edge)
    toGo = []
    edges.each do |e|
      if !(e == edge)
        toGo.push(e)
      end
    end
    return toGo
  end
  
  def edgesToGo(edges, p1, p2)
    toGo = []
    edges.each do |e|
      if !((e.used_by? p1) && (e.used_by? p2))
        toGo.push(e)
      end
    end
    return toGo
  end
  
  def nextPoint(edges, currentPoint)
    relEdges = []
    # suche alle edges an diesem Punkt
    edges.each do |e|
      if (e.used_by? currentPoint)
        relEdges.push(e)
      end
    end
   
    if relEdges.count == 0
      return nil                #abbruch, keine neuen kannten gefunden
    end
    
    
    newEdge = relEdges[0]
    relEdges.each do |e|
      newEdge = nextEdge(newEdge, e, currentPoint)
    end
    
    p = newEdge.other_vertex currentPoint
    puts("Nächster Punkt #{p.position}")
    return p
  
  end
  
  def nextEdge(e1, e2, p)
    p1 = e1.other_vertex p
    p2 = e2.other_vertex p
    if upperPoint(p1, p2) == p1 
      return e1
    else
      return e2
    end
  end
  
end






# Add a menu for Tool
if (not $fcToolPPLoaded)
  puts("Load Tool PP menu")
  UI.menu("Plugins").add_item("FoamCutter Tool PP") {
    loadConfig()
    cutterpp = FCutterPP.new
    cutterpp.labelX = @config["labelXAxis"]
    cutterpp.labelY = @config["labelYAxis"]
    cutterpp.labelU = @config["labelUAxis"]
    cutterpp.labelZ = @config["labelZAxis"]
    cutterpp.places = @config["decimalPlaces"]
    cutterpp.units = @config["units"]
    cutterpp.hotwire = @config["hotwire"]
    cutterpp.feedSpeed = @config["feedSpeed"]
    Sketchup.active_model.select_tool cutterpp
  }
   $fcToolPPLoaded = true
end


class FCutterPP
  @@dx = 1.feet
  @@dy = 1.feet
  
  @leftPoints = {}
  @rightPoints = {}
  def labelX=(z)
    @labelX = z
  end
  def labelX
    @labelX
  end
  def labelY=(z)
    @labelY = z
  end
  def labelY
    @labelY
  end
  def labelU=(z)
    @labelU = z
  end
  def labelU
    @labelU
  end
  def labelZ=(z)
    @labelZ = z
  end
  def labelZ
    @labelZ
  end
  def places=(z)
    @places = z
  end
  def places
    @places
  end
  def units=(z)
    @units = z
  end
  def units
    @units
  end
  def feedSpeed=(z)
    @feedSpeed = z
  end
  def feedSpeed
    @feedSpeed
  end
  def hotwire=(z)
    @hotwire = z
  end
  def hotwire
    @hotwire
  end
  
  # 1. automatically called
  def initialize
      puts("initialize")
      # global storage for two click points
      @ip1 = Sketchup::InputPoint.new
      @ip2 = Sketchup::InputPoint.new
      @ip3 = Sketchup::InputPoint.new
      @ip4 = Sketchup::InputPoint.new
      reset()
  end

  # 2. reset the tool
  def reset
      puts("reset")
      # reset statemachine and click points
      @state = 0
      @ip1.clear
      @ip2.clear
      @ip3.clear
      @ip4.clear
      @drawn = false
      # wait for left button down event
      @shift_down_time = Time.now
      Sketchup::set_status_text "Select left side of machine"
      
  end
  

  def activate
      puts("activate")
      self.reset
      @drawn = false
  end

  def deactivate(view)
    puts("deactivate")
    view.invalidate
  end

  # 3 + 4 + 5 + 6 left button down event
  def onLButtonDown(flags, x, y, view)
      puts("onLButtonDown")
      self.setSelectedPath(x, y, view)
      #self.increment_state
      view.lock_inference
  end

  def onLButtonUp(flags, x, y, view)
      puts("onLButtonUp")
  end
  
 
  def onCancel(flag, view)
     puts("onCancel")
     reset()
     Sketchup.active_model.select_tool nil
  end
  
  # 3a + 4a + 5a + 6a statemachine
  def setSelectedPath(x, y, view)
    puts("setSelectedPath")
      
    if (@state == 0)
        @ip1 = view.inputpoint x, y
        e = @ip1.edge
        if (e == nil)
          return false
        end
        puts("left machine selected")
        
        Sketchup::set_status_text "Select left path"
        @state = 1
        return true
    end
    if (@state == 1)
        @ip2 = view.inputpoint x, y
        e = @ip2.edge
        if (e == nil)
          return false
        end
        puts("left path selected")
        
        Sketchup::set_status_text "Select right path"
        @state = 2
        return true
    end
    if (@state == 2)
        @ip3 = view.inputpoint x, y
        e = @ip3.edge
        if (e == nil)
          return false
        end
        puts("left path selected")
        
        Sketchup::set_status_text "Select right side of machine"
        @state = 3
        return true
    end
    if (@state == 3)
        @ip4 = view.inputpoint x, y
        e = @ip4.edge
        if (e == nil)
          return false
        end
          
        
        generateGCode()
        
        Sketchup.active_model.select_tool nil
        return true
    end
  end

  def generateGCode()
    if (@ip1.edge == nil || @ip2.edge == nil || @ip3.edge == nil || @ip4.edge == nil)
      UI.messagebox('unable to generate path, no edge selected')
      return false
    end
    
    @leftMachine    = []
    @rightMachine   = [] 
    @leftPoints     = []
    @rightPoints    = []
    # generate the pathes
    @leftMachine    = getPathFrom(@ip1.edge)
    @rightMachine   = getPathFrom(@ip4.edge)
    @leftPoints     = getPathFrom(@ip2.edge)
    @rightPoints    = getPathFrom(@ip3.edge)
    
    file = UI.savepanel "GCode File", "c:\\", "default.gcode"
    if file
      if @leftPoints.count != @rightPoints.count
        puts("Left #{@leftPoints.count} Right #{@rightPoints.count}")
        UI.messagebox('the number of points in the two paths are not equal')
      end
      
   
      if @leftPoints.count > @rightPoints.count
        length = @leftPoints.count
      else 
        length = @rightPoints.count
      end
      
      i = 0
      x = 0
      y = 0
      u = 0
      z = 0
      
      mx = 0
      my = 0
      mu = 0
      mz = 0
      
      
      shapeWidth = 50.mm
      shapeLeftSpacing = 100.mm
      machineWidth = 721.mm
      machineLeft = 0.mm
      machineRight = 721.mm
      shapeRightSpacing = machineWidth - shapeWidth - shapeLeftSpacing
      
      s = 0
      
      puts("places: #{places}")
      puts("units: #{units}")
      
      model = Sketchup.active_model
      entities = model.active_entities
      group = entities.add_group()
      
      firstpoint = true
      lpoint1 = Geom::Point3d.new(0,0,0)
      rpoint1 = Geom::Point3d.new(0,0,0)
      #                             x,y
      
      outputfile = File.new( file , "w" )
      outputfile.puts("G17")
      outputfile.puts("G94")
      outputfile.puts("G90F#{feedSpeed}S#{hotwire}") 
      outputfile.puts("G4P1")
      outputfile.puts("M3")
      outputfile.puts("G4P5")
      

	  while i < length
         if i < @leftPoints.count
           x = @leftPoints[i].position.y
           y = @leftPoints[i].position.z
           u = @rightPoints[i].position.y
           z = @rightPoints[i].position.z
         
           if (i == 0)
             # on the first point, check the width and distances of shapes and machine
             machineLeft = @leftMachine[0].position.x
             machineRight = @rightMachine[0].position.x
             machineWidth = machineRight - machineLeft
             shapeWidth = @rightPoints[0].position.x - @leftPoints[0].position.x
             shapeLeftSpacing = @leftPoints[0].position.x - machineLeft
             shapeRightSpacing = machineWidth - shapeWidth - shapeLeftSpacing
             
           end
         
           s = (u - x) / shapeWidth
           mx = x - (s * shapeLeftSpacing)
           mu = u + (s * shapeRightSpacing)
         
           s = (z - y) / shapeWidth
           my = y - (s * shapeLeftSpacing)
           mz = z + (s * shapeRightSpacing)
           
           
           #draw the path of the machine
           lpoint2 = Geom::Point3d.new(machineLeft,mx,my)
           rpoint2 = Geom::Point3d.new(machineRight,mu,mz)
           
           if (firstpoint == false)
             group.entities.add_line lpoint1,lpoint2
             group.entities.add_line rpoint1,rpoint2
           end
           firstpoint = false
           lpoint1 = lpoint2
           rpoint1 = rpoint2
           
           # convert points to mm/inch
           mx = roundToPlaces(mx, places, units)
           my = roundToPlaces(my, places, units)
           mu = roundToPlaces(mu, places, units)
           mz = roundToPlaces(mz, places, units)
         end
                    puts("G1#{labelX}#{mx}#{labelY}#{my}#{labelU}#{mu}#{labelZ}#{mz}")
         outputfile.puts("G1#{labelX}#{mx}#{labelY}#{my}#{labelU}#{mu}#{labelZ}#{mz}")
         i += 1
      end
      
      group.material = "red"
   
      
      outputfile.puts("G4P1")
      outputfile.puts("M5")
      
      outputfile.close
      #@outputfile.puts("G00 X#{@pos_x} Y#{@pos_y} ")
      UI.messagebox('Ready')
     
    else
      UI.messagebox('Unable to generate file')
      return false
    end
 
  end
  
  def getPathFrom(edge) 
    
    currentPoint  = Sketchup::Vertex.new
    nextPoint     = Sketchup::Vertex.new
    edges         = []
    path          = []
    
    # ermittle alle verbundenen edges
    entities = edge.all_connected
    entities.each do |e|
      if (e.is_a? Sketchup::Edge)
        edges.push(e)
      end
    end
     
    # ermittle welcher der startpunkt ist
    currentPoint  = firstPoint(edges, edge.start, edge.end)
    # übernehme den ersten Punkt
    path.push(currentPoint)
    # ermittle den zweiten punkt
    nextPoint     = edge.other_vertex currentPoint
     
    while nextPoint != nil
      path.push(nextPoint)
      # ermittle die verbleibenden Kannten
      edges = edgesToGo(edges, currentPoint, nextPoint)
      # einen punkt weiterschalten
      currentPoint = nextPoint
      # nächsten Punkt ermitteln
      nextPoint = nextPoint(edges, currentPoint)
    end
   
    return path
  end
  
  
  def firstPoint(edges, p1, p2) 
      used = 0 
      edges.each do |e|
        if (e.used_by? p1)
          used += 1
        end
      end
      if used == 2
        return p2
      else
        return p1
      end
  end
  
  def upperPoint(p1, p2) 
    if (p1.position.z > p2.position.z)
      return p1
    elsif (p1.position.z < p2.position.z) 
      return p2
    elsif (p1.position.y < p2.position.y)
      return p1
    else  
      return p2
    end
  end
  
  def edgesToGo(edges, edge)
    toGo = []
    edges.each do |e|
      if !(e == edge)
        toGo.push(e)
      end
    end
    return toGo
  end
  
  def edgesToGo(edges, p1, p2)
    toGo = []
    edges.each do |e|
      if !((e.used_by? p1) && (e.used_by? p2))
        toGo.push(e)
      end
    end
    return toGo
  end
  
  def nextPoint(edges, currentPoint)
    relEdges = []
    # suche alle edges an diesem Punkt
    edges.each do |e|
      if (e.used_by? currentPoint)
        relEdges.push(e)
      end
    end
   
    if relEdges.count == 0
      return nil                #abbruch, keine neuen kannten gefunden
    end
    
    
    newEdge = relEdges[0]
    relEdges.each do |e|
      newEdge = nextEdge(newEdge, e, currentPoint)
    end
    
    p = newEdge.other_vertex currentPoint
    puts("Nächster Punkt #{p.position}")
    return p
  
  end
  
  def nextEdge(e1, e2, p)
    p1 = e1.other_vertex p
    p2 = e2.other_vertex p
    if upperPoint(p1, p2) == p1 
      return e1
    else
      return e2
    end
  end
  
end
