import Foundation
import SceneKit
import SwiftUI
import AppKit

// ============================================================================================================================
//
// FCalc: Calculates the movements for a 4 axis foam cutter based on a given shape and the machine settings
//
// Usage:
// - Settings:
//   all settings have a unique ID (see SettingsTableKey for all values) for access
//   Functions to access / change the settings
//   Reading:
//   - dataTypeForKey(_ key: SettingsTableKey) -> DataType              the Datatype of the Setting
//   - labelForKey(_ key: SettingsTableKey) -> String                   the label for the setting
//   - valueForKey(_ key: SettingsTableKey) -> String                   the value for the key as formatted string
//   Writing:
//   - isEditableForKey(_ key: SettingsTableKey) -> Bool                indicates wheather this type is editable
//   - isValueValid(_ key: SettingsTableKey, value: String?) -> Bool    a string can be tested, if it is accepted
//                                                                      for this setting
//   - valueForKey(_ key: SettingsTableKey, value: String?)             writes a string to the setting
//   Usage: Generate an array of SettingsTableKey-values to be displayed and catch the content with the functions above
//          all is handled with strings, so no need of type conversion
//
//
// - Load a file. Supported filetypes
//   gcode, nc: simple gcode wit G00/G0, G01, G1, G90, G91, ...
//   how: Winghelper ICE export with absolute coordinates
//   loadShapeFromFile(_ file: String) -> Int       =  0 if ok
//                                                  != 0 if not ok
//
// - Save a file in gcode format
//   saveGCodeToFile(_ file: String) -> Int         =  0 if ok
//                                                  != 0 if not ok
// - Values / Coordinates:
//   all coordinates are stored in an internal class-array.
//   access is given with the index and a uniquie ID (see PositionTableKey)
//   Functions to access / change the settings
//   Read:
//   - numberOfPositions
//   - valueFor(_ key: PositionTableKey, index: Int) -> String?
//   Write / Change:
//   - isValueValid(_ key: PositionTableKey, index: Int, value: String?) -> Bool  a string can be tested, if it is accepted
//                                                                                for this value
//   - valueFor(_ key: PositionTableKey, index: Int, value: String?)              writes a string to this value
//   - deleteIndex(_ index: Int)                                                  deletes a index
//   - addIndex(_ index: Int)                                                     adds a line before the index
//   Usage: get the numberOfPositions to generate a table and catch the content with the functions above
//          all is handled with strings, so no need of type conversion
//
// - Callbacks (FCalcCallback):
//   - updatePositionsTableView(_ atIndex: Int?)                                 called, wenn the table for the positions needs to be updated
//   - updateSettingsTableView()                                                 called, wenn the table for the settings needs to be updated
//   - updatePreview(_ node: SCNNode)                                            called, whenn the Graph is updated, check if Node is already linked
//
//
//  TODOs:
//  setCamera is not working, when the position is changes once manual
//  add an additional shape (incl positioning and mirror)
//  save a file including all settings / load a file
//
protocol FCalcCallback {
    func updatePositionsTableView(_ atIndex: Int?)
    func updatePreview(_ node: SCNNode)
    func updateSettingsTableView()
}


class FCalc {
    public var callback:    FCalcCallback?                              = nil
    public enum cameraDirection: Int {
        case front
        case top
        case left
        case right
    }
    
    public enum SettingsTableKey: Int  {
        case none
        case spacer
        case cutter
        case cutterWidth
        case cutterHeight
        case cutterDepth
        case labelX1Axis
        case labelY1Axis
        case labelX2Axis
        case labelY2Axis
        case gcodeDecimals
        case targetFeedSpeed
        case feedSpeedCorrection
        case maxFeedSpeed
        case fastPretravel
        case pretravelSpeed
        case hotwirePower
        case hotwirePreheat
  
        case block
        case blockWidth
        case blockHeight
        case blockDepth
        case blockSpacingLeft
        case blockSpacingFront
        case blockSpacingUnder
        case blockRotation
        
        case shape
        case shapeWidth
        case shapeSpacingLeft
        case shapeRotation
        case shapeX
        case shapeY
        case shapeMirror
        case shapeFlip
        
        case chart
        case showCutterGraph
        case showAxisGraph
        case showBlockGraph
        case showShapeGraph
        case showShapeCutGraph
        
        
    }
    
    public enum PositionTableKey: Int  {
        case x1Axis
        case y1Axis
        case x2Axis
        case y2Axis
        case x1Block
        case y1Block
        case w1Block
        case x2Block
        case y2Block
        case w2Block
        case x1Shape
        case y1Shape
        case w1Shape
        case x2Shape
        case y2Shape
        case w2Shape
        case hotwire
        case pretravel
        case none
    }
    
    
    
    public var      name:                       String?                 = nil
    public var      file:                       String?                 = nil
    public var      allowedFileTypes                                    = ["how","gcode", "nc"]
    
    // Achsenlabels für GCode export
    private var     labelX1Axis:                String                  = "X"
    private var     labelY1Axis:                String                  = "Y"
    private var     labelX2Axis:                String                  = "U"
    private var     labelY2Axis:                String                  = "Z"

    private var     gcodeDecimals:              UInt                    = 2
    
    // Cutter Dimension
    private var     cutterWidth:                Double                  = 721.0
    private var     cutterHeight:               Double                  = 220.0
    private var     cutterDepth:                Double                  = 350.0
    
    
    // Foam Block Dimensions
    private var     blockWidth:                 Double                  = 500.0
    private var     blockHeight:                Double                  = 100.0
    private var     blockDepth:                 Double                  = 100.0
    
    // Foam Block Position
    private var     blockSpacingLeft:           Double                  = 100.0
    private var     blockSpacingFront:          Double                  = 0.0
    private var     blockSpacingUnder:          Double                  = 0.0
    private var     blockRotation:              Double                  = 0.0
    
    // Shape Position Correction
    private var     shapeWidth:                 Double                  = 500.0
    private var     shapeSpacingLeft:           Double                  = 100.0
    private var     shapeRotation:              Double                  = 0.0
    private var     shapeX:                     Double                  = 0.0
    private var     shapeY:                     Double                  = 0.0
    private var     shapeMirror:                Bool                    = false
    private var     shapeFlip:                  Bool                    = false
    // Hotwire and Speed Adjustment
    private var     targetFeedSpeed:            UInt                    = 300   // mm/min
    private var     feedSpeedCorrection:        Bool                    = true
    private var     maxFeedSpeed:               UInt                    = 1500  // mm/min
    private var     hotwirePower:               UInt                    = 90    // in %
    private var     hotwirePreheat:             UInt                    = 5
    private var     fastPretravel:              Bool                    = true
    private var     pretravelSpeed:             UInt                    = 1000  // mm/min
    
     
    // Parameter für die Darstellung als Graphen
    private var     axisColor:                  NSColor                 = NSColor.orange.withAlphaComponent(0.4)
    private var     axisColorHotwire:           NSColor                 = NSColor.orange
    private var     axisColorAlert:             NSColor                 = NSColor.red
    private var     shapeColor:                 NSColor                 = NSColor.blue.withAlphaComponent(0.4)
    private var     shapeColorHotwire:          NSColor                 = NSColor.blue
    private var     blockColor:                 NSColor                 = NSColor.black
    private var     cutterColor:                NSColor                 = NSColor.gray
    private var     wireColor:                  NSColor                 = NSColor.red
    
    private var     showAxisGraph:              Bool                    = false
    private var     showShapeGraph:             Bool                    = true
    private var     showCutterGraph:            Bool                    = true
    private var     showBlockGraph:             Bool                    = true
    private var     showShapeCutGraph:          Bool                    = true
    
    // die Graphen für Charts Scatterplot
    private var previewNode:                    SCNNode                 = SCNNode()
    private var cameraNode:                     SCNNode                 = SCNNode()
    
    private var blockNode:                      SCNNode                 = SCNNode()
    private var cutterNode:                     SCNNode                 = SCNNode()
    private var shapeNode:                      SCNNode                 = SCNNode()
    private var shapeCutNode:                   SCNNode                 = SCNNode()
    private var axisNode:                       SCNNode                 = SCNNode()
    private var wireNode:                       SCNNode                 = SCNNode()
    private var simulationTimer:                Timer?                  = nil

    // hierin liegen die eigentlichen Daten
    private var positions:                      [CuttingPosition]       = Array()
    public var numberOfPositions:               Int {
        get {
            return positions.count
        }
        set {
            
        }
    }
    public var     markedPosition:              Int?                    = nil {
        didSet {
            updateWireNode()
        }
    }
    
    
    
        
    private class CuttingPosition {
        var x1Shape:                    Double                 = 0.0       // die originalen Shape daten
        var y1Shape:                    Double                 = 0.0
        var w1Shape:                    Double                 = 0.0
        var x2Shape:                    Double                 = 0.0
        var y2Shape:                    Double                 = 0.0
        var w2Shape:                    Double                 = 0.0
        
        var x1Axis:                     Double                  = 0.0       // die Achsenpositionen... wird berechnet
        var y1Axis:                     Double                  = 0.0
        var x2Axis:                     Double                  = 0.0
        var y2Axis:                     Double                  = 0.0
        
        var x1Block:                    Double                  = 0.0       // die Schnittstelle am Block... wird berechnet
        var y1Block:                    Double                  = 0.0
        var w1Block:                    Double                  = 0.0
        var x2Block:                    Double                  = 0.0
        var y2Block:                    Double                  = 0.0
        var w2Block:                    Double                  = 0.0
        
        
        var hotwire:                    Bool                    = true
        var pretravel:                  Bool                    = false
        var feedSpeed:                  Double?                 = nil
    
        var added:                      Bool                    = false
        
        var gcode:                      String                  = ""
    }
    public func loadShapeFromFile(_ file: String) -> Int {
        return loadShapeFromFile(file, add: false)
    }
    public func addShapeFromFile(_ file: String, index: Int? = nil) -> Int {
        let index = index ?? positions.count
        return loadShapeFromFile(file, add: true, index: index)
    }
    private func initShape() {
        positions.removeAll()
        
        // Shapeverschiebung löschen
        shapeX                          = 0.0
        shapeY                          = 0.0
        shapeRotation                   = 0.0
        shapeMirror                     = false
        shapeFlip                       = false
        blockRotation                   = 0.0
        
        stop()      // stop the simulation
        
        requestUpdateSettingsTable()
    }
    private func loadShapeFromFile(_ file: String, add: Bool = false, index: Int = 0) -> Int {
        
        //read text file line by line
        errno = 0
        if freopen(file, "r", stdin) == nil {
            perror(file)
            return -1
        }
        var index = index
        if index > positions.count {
            index = positions.count
        }
        
        var add = add
        if positions.count == 0 {
            add = false
        }
        
        if add == false {       // only for first file
            self.file       = file      // store filename incl path
            self.name       = URL(fileURLWithPath: file).deletingPathExtension().lastPathComponent
            initShape()
        } else {
            // ToDo hier die inits für das add machen
        }
        
        let fileExt     = URL(fileURLWithPath: file).pathExtension
        
        
        if (fileExt == "HOW") || (fileExt == "how") {
            while let line = readLine() {
                // NSLog(line)
                // decode line
                // split line by space
                var res = line.components(separatedBy: CharacterSet(charactersIn: " "))
                res.removeAll(where: { $0 == "" })
                
                if (res.count >= 3),
                   let x = Double(res[0]), let y = Double(res[1]), let u = Double(res[2]), let z = Double(res[3]) {
                    addShapeLine(x1: x,
                                 y1: y,
                                 w1: 0.0,
                                 x2: u,
                                 y2: z,
                                 w2: shapeWidth,
                                 index: index,
                                 add: add)
                    index += 1
                }
            }
            NSLog("File geladen: " + (self.name ?? ""))
        } else if (fileExt == "gcode") || (fileExt == "GCODE") || (fileExt == "nc") || (fileExt == "NC") {
            var x:                  Double = 0.0
            var y:                  Double = 0.0
            var u:                  Double = 0.0
            var z:                  Double = 0.0
            var modeRelativ:        Bool   = false
            var newPositionValues:  Bool   = false
            
            func decodeGcodeCommand(_ line: String?) -> String? {
                guard let line = line else {
                    return nil
                }
                if line.hasPrefix("G90") {
                    modeRelativ = false
                    return String(line.dropFirst("G90".count))
                }
                if line.hasPrefix("G91") {
                    modeRelativ = true
                    return String(line.dropFirst("G91".count))
                }
                if line.hasPrefix("G00") {
                    return String(line.dropFirst("G00".count))
                }
                if line.hasPrefix("G0") {
                    return String(line.dropFirst("G0".count))
                }
                if line.hasPrefix("G01") {
                    return String(line.dropFirst("G01".count))
                }
                if line.hasPrefix("G1") {
                    return String(line.dropFirst("G1".count))
                }
                if line.hasPrefix("G4") {
                    return String(line.dropFirst("G4".count))
                }
                if line.hasPrefix("M3") {
                    return String(line.dropFirst("M3".count))
                }
                if line.hasPrefix("M4") {
                    return String(line.dropFirst("M4".count))
                }
                if line.hasPrefix("M5") {
                    return String(line.dropFirst("M5".count))
                }
                return line // nil
            }
            
            func decodeGcodeValue(_ line: String?) -> String? {
                guard var line = line else {
                    return nil
                }
                
                if line.hasPrefix("X") {
                    line =  String(line.dropFirst("X".count))
                    let res = line.components(separatedBy: CharacterSet(charactersIn: "XYUZFSPMG"))
                    
                    if let v = Double(res[0]) {
                        line =  String(line.dropFirst(res[0].count))
                        newPositionValues   = true
                        if modeRelativ == true {
                            x = x + v
                        } else {
                            x = v
                        }
                    }
                    return line
                }
                if line.hasPrefix("Y") {
                    line =  String(line.dropFirst("Y".count))
                    let res = line.components(separatedBy: CharacterSet(charactersIn: "XYUZFSPMG"))
                    
                    if let v = Double(res[0]) {
                        line =  String(line.dropFirst(res[0].count))
                        newPositionValues   = true
                        if modeRelativ == true {
                            y = y + v
                        } else {
                            y = v
                        }
                    }
                    return line
                }
                if line.hasPrefix("U") {
                    line =  String(line.dropFirst("U".count))
                    let res = line.components(separatedBy: CharacterSet(charactersIn: "XYUZFSPMG"))
                    
                    if let v = Double(res[0]) {
                        line =  String(line.dropFirst(res[0].count))
                        newPositionValues   = true
                        if modeRelativ == true {
                            u = u + v
                        } else {
                            u = v
                        }
                    }
                    return line
                }
                if line.hasPrefix("Z") {
                    line =  String(line.dropFirst("Z".count))
                    let res = line.components(separatedBy: CharacterSet(charactersIn: "XYUZFSPMG"))
                    
                    if let v = Double(res[0]) {
                        line =  String(line.dropFirst(res[0].count))
                        newPositionValues   = true
                        if modeRelativ == true {
                            z = y + v
                        } else {
                            z = v
                        }
                    }
                    return line
                }
                if line.hasPrefix("F") {
                    line =  String(line.dropFirst("F".count))
                    let res = line.components(separatedBy: CharacterSet(charactersIn: "XYUZFSPMG"))
                    
                    if Double(res[0]) != nil {
                        line =  String(line.dropFirst(res[0].count))
                    }
                    return line
                }
                if line.hasPrefix("S") {
                    line =  String(line.dropFirst("S".count))
                    let res = line.components(separatedBy: CharacterSet(charactersIn: "XYUZFSPMG"))
                    
                    if Double(res[0]) != nil {
                        line =  String(line.dropFirst(res[0].count))
                    }
                    return line
                }
                if line.hasPrefix("P") {
                    line =  String(line.dropFirst("P".count))
                    let res = line.components(separatedBy: CharacterSet(charactersIn: "XYUZFSPMG"))
                    
                    if Double(res[0]) != nil {
                        line =  String(line.dropFirst(res[0].count))
                    }
                    return line
                }
                if line.hasPrefix("M") {
                    line =  String(line.dropFirst("M".count))
                    let res = line.components(separatedBy: CharacterSet(charactersIn: "XYUZFSPMG"))
                    
                    if Double(res[0]) != nil {
                        line =  String(line.dropFirst(res[0].count))
                    }
                    return line
                }
                if line.hasPrefix("G") {
                    line =  String(line.dropFirst("G".count))
                    let res = line.components(separatedBy: CharacterSet(charactersIn: "XYUZFSPMG"))
                    
                    if Double(res[0]) != nil {
                        line =  String(line.dropFirst(res[0].count))
                    }
                    return line
                }
                
                return nil
            }
            
            while var line = readLine() {
                // NSLog(line)
                // decode line
                line = line.uppercased()
                line = line.components(separatedBy: .whitespacesAndNewlines).joined() //trimmingCharacters(in: .whitespacesAndNewlines)
                newPositionValues = false
                if var line = decodeGcodeCommand(line)  {
                    // valid command, decode letters
                    while let newline = decodeGcodeValue(line) {
                        line = newline
                    }
                    if newPositionValues == true {
                        addShapeLine(x1: x,
                                     y1: y,
                                     w1: 0.0,
                                     x2: u,
                                     y2: z,
                                     w2: shapeWidth,
                                     index: index,
                                     add: add)
                        index += 1
                    }
                    
                }
            }
            NSLog("File geladen: " + (self.name ?? ""))
            
        } else {
            return -1
        }
        // alles neu berechnen
        _ = calculateShape()
        // graph aufbauen
        _ = generateGraph()
        return 0
    }
    
    // still under construction
    private func addShapeLine( x1:       Double,
                               y1:       Double,
                               w1:       Double,
                               x2:       Double,
                               y2:       Double,
                               w2:       Double,
                               index:   Int         = 0,
                               add:     Bool        = false) {
        
        let position:       CuttingPosition         = CuttingPosition()
        position.x1Shape     = x1
        position.y1Shape     = y1
        position.w1Shape     = w1
        position.x2Shape     = x2
        position.y2Shape     = y2
        position.w2Shape     = w2
        position.added       = add
        
        positions.insert(position, at: index)
    }
    private func moveShape(_ x: Double, _ y: Double) {
        for position in positions {
            position.x1Shape    +=  x
            position.x2Shape    +=  x
            position.y1Shape    +=  y
            position.y2Shape    +=  y
        }
    }
    private func mirrorShape() {
        var mem: Double
        var minW: Double        = positions.first?.w1Shape  ?? 0.0
        var maxW: Double        = positions.first?.w1Shape  ?? 0.0
        for position in positions {
            if position.w1Shape > maxW        { maxW = position.w1Shape }
            if position.w2Shape > maxW        { maxW = position.w2Shape }
            if position.w1Shape < minW        { minW = position.w1Shape }
            if position.w2Shape < minW        { minW = position.w2Shape }
        }
        
        for position in positions {
            mem                 = position.x1Shape
            position.x1Shape    = position.x2Shape
            position.x2Shape    = mem
            mem                 = position.y1Shape
            position.y1Shape    = position.y2Shape
            position.y2Shape    = mem
            
            mem                 = position.w1Shape
            position.w1Shape    = maxW - position.w2Shape + minW
            position.w2Shape    = maxW - (mem - minW)
        }
    }
    private func flipShape() {
        var mem: Double
        var minX: Double        = positions.first?.x1Shape  ?? 0.0
        var minY: Double        = positions.first?.y1Shape  ?? 0.0
        var maxX: Double        = positions.first?.x1Shape  ?? 0.0
        var maxY: Double        = positions.first?.y1Shape  ?? 0.0
        
        // find min and max dimensions
        for position in positions {
            if position.x1Shape > maxX        { maxX = position.x1Shape }
            if position.x2Shape > maxX        { maxX = position.x2Shape }
            if position.y1Shape > maxY        { maxY = position.y1Shape }
            if position.y2Shape > maxY        { maxY = position.y2Shape }
            if position.x1Shape < minX        { minX = position.x1Shape }
            if position.x2Shape < minX        { minX = position.x2Shape }
            if position.y1Shape < minY        { minY = position.y1Shape }
            if position.y2Shape < minY        { minY = position.y2Shape }
        }
        
        // flipp and store into new array reverse sorted
        var flippedPositions: [CuttingPosition] = []
        for position in positions {
            mem                 = maxX - position.x1Shape
            position.x1Shape    = minX + mem
            mem                 = maxX - position.x2Shape
            position.x2Shape    = minX + mem
            mem                 = maxY - position.y1Shape
            position.y1Shape    = minY + mem
            mem                 = maxY - position.y2Shape
            position.y2Shape    = minY + mem
            
            flippedPositions.insert(position, at: 0)
        }
        
        // remove old positions
        positions.removeAll()       // TODO keep added/pretravel,... in mind
        
        // add the flipped positions
        positions   += flippedPositions
        
    }
    private func calculateShape() -> Int {
         
        guard positions.count > 0 else {
            NSLog("Keine Daten vorhanden")
            
            return -1;
        }
        
        var lastPosition : CuttingPosition? = nil
        for position in positions {
            calculatePosition(position, lastPosition: lastPosition)
            lastPosition    = position
        }
        // Aktualisierungs-Callback aufrufen
        requestUpdatePositionsTable(nil)
        return 0;
    }
    private func calculatePosition(_ position: CuttingPosition, source: PositionTableKey = .x1Shape, lastPosition: CuttingPosition? = nil) {
        var left:                       Double      = 0.0
        var right:                      Double      = 0.0
        var delta:                      Double      = 0.0
        
        
        if (source == .x1Shape) || (source == .y1Shape) || (source == .x2Shape) || (source == .y2Shape) {
      
            
            // still under construction with the add functions
            
            
            /*
            shapeOffset     = self.shapeX
            if position.pretravel {
                shapeOffset = 0.0
            }
            if position.added {
                shapeOffset = 0.0
            }
            */
            
            
            position.x1Block = position.x1Shape * cos(-shapeRotation)
                             - position.w1Shape * sin(-shapeRotation)
                             + self.shapeX
            
            position.w1Block = position.x1Shape * sin(-shapeRotation)
                             + position.w1Shape * cos(-shapeRotation)
                             + self.shapeSpacingLeft
            
            position.y1Block = position.y1Shape
                             + self.shapeY
             
            position.x2Block = position.x2Shape * cos(-shapeRotation)
                             - position.w2Shape * sin(-shapeRotation)
                             + self.shapeX
             
            position.w2Block = position.x2Shape * sin(-shapeRotation)
                             + position.w2Shape * cos(-shapeRotation)
                             + self.shapeSpacingLeft
             
            position.y2Block = position.y2Shape
                             + self.shapeY
            
                
            delta               = (position.x2Block - position.x1Block) / (position.w2Block - position.w1Block)     // berechne die steigung
            right               = cutterWidth - position.w2Block
            left                = position.w1Block
            position.x1Axis     = (position.x1Block) - (delta * left)        // berechne die x1Achse
            position.x2Axis     = (position.x2Block) + (delta * right)       // berechne die x2Achse
            delta               = (position.y2Block - position.y1Block) / (position.w2Block - position.w1Block)     // berechne die steigung
            position.y1Axis     = (position.y1Block) - (delta * left)        // berechne die x1Achse
            position.y2Axis     = (position.y2Block) + (delta * right)       // berechne die x2Achse
             
        } else if (source == .x1Axis) || (source == .y1Axis) || (source == .x2Axis) || (source == .y2Axis) {
            
            delta               = (position.y2Axis - position.y1Axis) / cutterWidth    // berechne die steigung
            right               = cutterWidth - position.w2Block
            left                = position.w1Block
            position.y1Block    = position.y1Axis    + (delta * left)        // berechne die y1Achse
            position.y2Block    = position.y2Axis    - (delta * right)       // berechne die y2Achse
            
            delta               = (position.x2Axis - position.x1Axis) / cutterWidth    // berechne die steigung
            right               = cutterWidth - position.w2Block
            left                = position.w1Block
            position.x1Block    = position.x1Axis    + (delta * left)        // berechne die x1Achse
            position.x2Block    = position.x2Axis    - (delta * right)       // berechne die x2Achse
            
            
            position.y1Shape    = position.y1Block
                                - self.shapeY
            position.y2Shape    = position.y2Block
                                - self.shapeY
            
            var x:  Double      = 0.0
            var w:  Double      = 0.0
            
            x                   = position.x1Block - self.shapeX
            w                   = position.w1Block - self.shapeSpacingLeft
            position.x1Shape = x * cos(shapeRotation)
                             - w * sin(shapeRotation)
            position.w1Shape = x * sin(shapeRotation)
                             + w * cos(shapeRotation)
             
            x                   = position.x2Block - self.shapeX
            w                   = position.w2Block - self.shapeSpacingLeft
            position.x2Shape = x * cos(shapeRotation)
                             - w * sin(shapeRotation)
            position.w2Shape = x * sin(shapeRotation)
                             + w * cos(shapeRotation)
            
        }
        
        // berechne die bearbeitungsgeschwindigkeit
        var calcFeedSpeed:      Double = Double(targetFeedSpeed)
        if let lastPosition = lastPosition {
            // berechne die Strecke am Block und an der Achse
            var dBlock:         Double = 0
            var dAxis:          Double = 0
            var dSpeed:         Double = 1
            
            
            dBlock       = (position.x1Block - lastPosition.x1Block) * (position.x1Block - lastPosition.x1Block)
            dBlock      += (position.y1Block - lastPosition.y1Block) * (position.y1Block - lastPosition.y1Block)
            dBlock      += (position.w1Block - lastPosition.w1Block) * (position.w1Block - lastPosition.w1Block)
            dBlock       = sqrt(dBlock)
            
            dAxis        = (position.x1Axis - lastPosition.x1Axis) * (position.x1Axis - lastPosition.x1Axis)
            dAxis       += (position.y1Axis - lastPosition.y1Axis) * (position.y1Axis - lastPosition.y1Axis)
            dAxis        = sqrt(dAxis)
            
            // Ermittle das Verhältnis von Block zu Achse
            dSpeed       = dAxis / dBlock
            
            dBlock       = (position.x2Block - lastPosition.x2Block) * (position.x2Block - lastPosition.x2Block)
            dBlock      += (position.y2Block - lastPosition.y1Block) * (position.y2Block - lastPosition.y2Block)
            dBlock      += (position.w2Block - lastPosition.w2Block) * (position.w2Block - lastPosition.w2Block)
            dBlock       = sqrt(dBlock)
             
            dAxis        = (position.x2Axis - lastPosition.x2Axis) * (position.x2Axis - lastPosition.x2Axis)
            dAxis       += (position.y2Axis - lastPosition.y2Axis) * (position.y2Axis - lastPosition.y2Axis)
            dAxis        = sqrt(dAxis)
            
            if dSpeed < (dAxis / dBlock) {
                dSpeed   = dAxis / dBlock
            }
            
            if dSpeed.isInfinite {
                calcFeedSpeed   = Double(maxFeedSpeed)
            } else if dSpeed.isNaN {
                calcFeedSpeed   = Double(targetFeedSpeed)
            }  else if dSpeed <= 0.0 {
                calcFeedSpeed   = Double(targetFeedSpeed)
            } else {
                calcFeedSpeed  = dSpeed * Double(targetFeedSpeed)
            }
        }
        
        position.feedSpeed      = calcFeedSpeed
        if fastPretravel == true,
            position.pretravel == true {
            position.feedSpeed      = Double(pretravelSpeed)
        }
        if let speed = position.feedSpeed {
            if speed > Double(maxFeedSpeed) {
                position.feedSpeed      = Double(maxFeedSpeed)
            }
        } else {
            position.feedSpeed      = Double(targetFeedSpeed)
        }
        
    }
    init() {
        _ = initializeGraph()
        _ = generateGraph()
    }
    
    private func initializeGraph() -> Int {
        cameraNode                  = SCNNode()
        cameraNode.camera           = SCNCamera()
        cameraNode.camera!.zFar     = (max(cutterWidth, cutterHeight) + cutterDepth) * 3;
        cameraNode.camera!.zNear    = 5.0;
        
        // mittig
        cameraNode.position         = SCNVector3(x: CGFloat(cutterWidth * 0.5),
                                                 y: 0,
                                                 z: CGFloat(cameraNode.camera!.zFar / 2))
        cameraNode.eulerAngles      = SCNVector3(x: .pi * 0.0,
                                                 y: .pi * 0.0,
                                                 z: .pi * 0.0)
        previewNode.addChildNode(cameraNode)
        
        previewNode.light           = SCNLight()
        previewNode.light!.type = .ambient
        previewNode.light!.color = NSColor(white: 0.67, alpha: 1.0)
        
        return 0
    }
    public func setCamera(_ direction: cameraDirection = .front) {
        switch (direction) {
        case .top:
            cameraNode.position = SCNVector3(x: CGFloat(cutterWidth * 0.5),
                                             y: CGFloat(cameraNode.camera!.zFar * 0.5 + cutterHeight),
                                             z: 0)
            cameraNode.eulerAngles      = SCNVector3(x: .pi * -0.5,
                                                     y: .pi * 0.0,
                                                     z: .pi * 0.0)
            break
        case .left:
            cameraNode.position = SCNVector3(x: CGFloat(cameraNode.camera!.zFar * -0.5),
                                             y: 0,
                                             z: CGFloat(cutterDepth * -0.5))
            cameraNode.eulerAngles      = SCNVector3(x: .pi * 0.0,
                                                     y: .pi * -0.5,
                                                     z: .pi * 0.0)
            break
        case .right:
            cameraNode.position = SCNVector3(x: CGFloat(cameraNode.camera!.zFar * 0.5 + cutterWidth),
                                             y: 0,
                                             z: CGFloat(cutterDepth * -0.5))
            cameraNode.eulerAngles      = SCNVector3(x: .pi * 0.0,
                                                     y: .pi * 0.5,
                                                     z: .pi * 0.0)
            break
        default:
            cameraNode.position = SCNVector3(x: CGFloat(cutterWidth * 0.5),
                                             y: 0,
                                             z: CGFloat(cameraNode.camera!.zFar * 0.5))
            cameraNode.eulerAngles      = SCNVector3(x: .pi * 0.0,
                                                     y: .pi * 0.0,
                                                     z: .pi * 0.0)
            break
            
        }
    }
    
    
    private func generateGraph() -> Int {
        defer {
            if let f = callback?.updatePreview(_:) {
                f(previewNode)
            }
        }
        
        blockNode.removeFromParentNode()
        cutterNode.removeFromParentNode()
        shapeNode.removeFromParentNode()
        shapeCutNode.removeFromParentNode()
        axisNode.removeFromParentNode()
        stop()      // stop the simulation
        
        blockNode       = generateFoamBlockeNode(x: blockSpacingFront,
                                                     y: blockSpacingUnder,
                                                     w: blockSpacingLeft,
                                                     depth: blockDepth,
                                                     height: blockHeight,
                                                     width: blockWidth,
                                                     rotationY: blockRotation,
                                                     color: blockColor,
                                                     edgeColor: blockColor)
        blockNode.isHidden       = !self.showBlockGraph
        previewNode.addChildNode(blockNode)
        
        cutterNode           = generateCutterNode(depth:        cutterDepth,
                                                  height:       cutterHeight,
                                                  width:        cutterWidth,
                                                  color:        cutterColor,
                                                  edgeColor:    cutterColor)
        cutterNode.isHidden  = !self.showCutterGraph
        previewNode.addChildNode(cutterNode)
                
        
        shapeNode            = generateShapeNode()
        shapeNode.isHidden   = !self.showShapeGraph
        previewNode.addChildNode(shapeNode)
        
        shapeCutNode         = generateShapeCutNode()
        shapeCutNode.isHidden   = !self.showShapeCutGraph
        previewNode.addChildNode(shapeCutNode)
        
        axisNode             = generateAxisNode()
        axisNode.isHidden    = !self.showAxisGraph
        previewNode.addChildNode(axisNode)
        
        guard positions.count > 0 else {
            NSLog("Keine Daten vorhanden")
            return -1;
        }
        
        return 0
    }
    
    func sin(_ degrees: Double) -> Double {
        return __sinpi(degrees/180.0)
    }
    func cos(_ degrees: Double) -> Double {
        return __cospi(degrees/180.0)
    }
    
    private func generateGCode() -> Int {
        guard positions.count > 0 else {
            NSLog("Keine Daten vorhanden")
            return -1;
        }
                
        var hotwire         = false
        var pretravelSpeed  = self.pretravelSpeed
        var targetFeedSpeed = self.targetFeedSpeed
        if pretravelSpeed > self.maxFeedSpeed {
            pretravelSpeed = self.maxFeedSpeed
        }
        if targetFeedSpeed > self.maxFeedSpeed {
            targetFeedSpeed = self.maxFeedSpeed
        }
        
        for position in positions {
            // erzeuge den G-Code
            position.gcode = ""
            if hotwire != position.hotwire {
                hotwire = position.hotwire
                if hotwire {            // hotwire wird eingeschalten
                    position.gcode += "G4P1\nM3\n"
                    position.gcode += "G4P" + String(hotwirePreheat) + "\n"      // Preheat für Hotwire
                } else {                // hotwire ausschalten
                    position.gcode += "G4P1\nM5\n"
                }
            }
            position.gcode              += "G1"
                
            if let feedSpeed = position.feedSpeed {
                position.gcode      += "F"        + dtos(feedSpeed, decimals: 0)
            } else {
                position.gcode      += "F"        + dtos(Double(targetFeedSpeed), decimals: 0)
            }
            
            position.gcode              += labelX1Axis + dtos(position.x1Axis, decimals: gcodeDecimals)
                                        +  labelY1Axis + dtos(position.y1Axis, decimals: gcodeDecimals)
                                        +  labelX2Axis + dtos(position.x2Axis, decimals: gcodeDecimals)
                                        +  labelY2Axis + dtos(position.y2Axis, decimals: gcodeDecimals)
        }
        return 0
    }
    
    public func saveGCodeToFile(_ file: String) -> Int {
        guard positions.count > 0 else {
            NSLog("Keine Daten vorhanden")
            return -1;
        }
        
        guard generateGCode() == 0 else {
            return -1
        }
        
        self.file       = file      // store filename incl path
        self.name       = URL(fileURLWithPath: file).deletingPathExtension().lastPathComponent
                
         
        // Schreibe in ie Header alle benötigten Einstellung
        var info: String
        
        info = "; FoamCutter G-Code";                                                                       writeLine(info, toFile: file, firstLine: true)
        info = "; ";                                                                                        writeLine(info, toFile: file)
        info = "; "    + labelForKey(.cutter)            + "  " + valueForKey(.cutter);                     writeLine(info, toFile: file)
        info = "; "    + labelForKey(.cutterWidth)       + "  " +  valueForKey(.cutterWidth);               writeLine(info, toFile: file)
        info = "; ";                                                                                        writeLine(info, toFile: file)
        info = "; "    + labelForKey(.block)             + "  " +  valueForKey(.block);                     writeLine(info, toFile: file)
        info = ";    " + labelForKey(.blockWidth)        + "  " +  valueForKey(.blockWidth);                writeLine(info, toFile: file)
        info = ";    " + labelForKey(.blockHeight)       + "  " +  valueForKey(.blockHeight);               writeLine(info, toFile: file)
        info = ";    " + labelForKey(.blockDepth)        + "  " +  valueForKey(.blockDepth);                writeLine(info, toFile: file)
        info = ";    " + labelForKey(.blockSpacingLeft)  + "  " +  valueForKey(.blockSpacingLeft);          writeLine(info, toFile: file)
        info = ";    " + labelForKey(.blockSpacingFront) + "  " +  valueForKey(.blockSpacingFront);         writeLine(info, toFile: file)
        info = ";    " + labelForKey(.blockSpacingUnder) + "  " +  valueForKey(.blockSpacingUnder);         writeLine(info, toFile: file)
        info = ";    " + labelForKey(.blockRotation)     + "  " +  valueForKey(.blockRotation);             writeLine(info, toFile: file)
        info = "; ";                                                                                        writeLine(info, toFile: file)
        
        
        // XY Plane / mm / Feedrate as unit per minut
        info = "G17\nG21\nG94";                                                                             writeLine(info, toFile: file)
        // Absolute Positionsangaben
        info = "G90F" + valueForKey(.targetFeedSpeed) + "S" + valueForKey(.hotwirePower);                   writeLine(info, toFile: file)
        
        // initiales Hotwire on / off
        if positions.first?.hotwire ?? false {
            info = "G4P1\nM3\nG4P" + String(hotwirePreheat)
        } else {
            info = "G4P1\nM5"
        }
        writeLine(info, toFile: file)
        
        for position in positions {
            writeLine(position.gcode, toFile: file)
        }
        // Hotwire am Ende ausschalten
        info = "G4P1\nM5\n"
        writeLine(info, toFile: file)
         
        
        NSLog("File exportiert: " + (self.name ?? ""))
        return 0
    }
    private func writeLine(_ line: String, toFile: String, firstLine: Bool = false) {
        if firstLine == true {
            try! line.write(to: URL(fileURLWithPath: toFile), atomically: true, encoding: .utf8)
        } else {
            let content = try! String(contentsOfFile: toFile, encoding: .utf8)
            try! (content  + "\n" + line)
                .write(toFile: toFile,
                       atomically: true,
                       encoding: .utf8)
        }
    }
    
     
    private func dtos(_ value: Double, decimals: UInt = 0, _ useLocalizedDecimalSeperator: Bool = false) -> String {
        let format = String(format:"%%0.%df", decimals)
        
        var string = String(format:format, value)
        if useLocalizedDecimalSeperator {
            string = string.replacingOccurrences(of: ".", with: "Komma".localized())
        }
        return string
    }
    private func btos(_ value: Bool) -> String {
        if value == true {
            return "1"
        } else {
            return "0"
        }
    }
    
    private func stod(_ value: String?, _ useLocalizedDecimalSeperator: Bool = false) -> Double {
        guard var value = value else {
            return 0.0
        }
        if useLocalizedDecimalSeperator {
            value = value.replacingOccurrences(of: "Komma".localized(), with: ".")
        }
        return Double(value) ?? 0.0
    }
    
    private func stoi(_ value: String?) -> Int {
        guard let value = value else {
            return 0
        }
        return Int(value) ?? 0
    }
    private func stoui(_ value: String?) -> UInt {
        guard let value = value else {
            return 0
        }
        return UInt(value) ?? 0
    }
    private func stob(_ value: String?) -> Bool {
        guard let value = value else {
            return false
        }
        if value == "1" {
            return true
        }
        return false
    }
 }



// Settings Interface
extension FCalc {
    public func requestUpdatePositionsTable(_ atIndex: Int?) {
    
        if let f = callback?.updatePositionsTableView(_:) {
            f(atIndex)
        }
 
    }
    public func requestUpdateSettingsTable() {
        if let f = callback?.updateSettingsTableView {
            f()
        }
    }
    
}

// MARK: - Simulation
extension FCalc {
    @objc public func play() {
        guard positions.count > 0 else {
            return
        }
        
        if markedPosition == nil {
            markedPosition = 0
        } else {
            markedPosition! += 1
        }
        
        
        // calculate the distance
        var time: TimeInterval      = 0.5
        if let index = markedPosition,
            (index + 1) < (positions.count) {
            let position        = positions[index]
            let nextPosition    = positions[index + 1]
            var d1Axis: Double
            var d2Axis: Double
            
            d1Axis      = (position.x1Axis - nextPosition.x1Axis) * (position.x1Axis - nextPosition.x1Axis)
            d1Axis     += (position.y1Axis - nextPosition.y1Axis) * (position.y1Axis - nextPosition.y1Axis)
            d1Axis      = sqrt(d1Axis)
            
            d2Axis      = (position.x2Axis - nextPosition.x2Axis) * (position.x2Axis - nextPosition.x2Axis)
            d2Axis     += (position.y2Axis - nextPosition.y2Axis) * (position.y2Axis - nextPosition.y2Axis)
            d2Axis      = sqrt(d2Axis)
            
            d1Axis      = max(d1Axis, d2Axis)
            
            time        = d1Axis / (position.feedSpeed ?? Double(targetFeedSpeed))
            time       *= 60    // mm/min >> seconds
            time       /= 10     // time elapse (fast)
        }
               
        simulationTimer =   Timer.scheduledTimer(timeInterval: time,
                                                 target: self,
                                                 selector: #selector(play),
                                                 userInfo: nil,
                                                 repeats: false)
    }
    
    public func pause() {
        simulationTimer?.invalidate()
        simulationTimer = nil
        
    }
    
    public func stop() {
        simulationTimer?.invalidate()
        simulationTimer = nil
        wireNode.removeFromParentNode()
        markedPosition  = nil
    }
    
    
}

// MARK: - Interface
extension FCalc {
    
    public enum DataType: Int {
        case none
        case header
        case double
        case uint
        case boolean
        case string
        case color
    }
    public func dataTypeForKey(_ key: SettingsTableKey) -> DataType {
        switch (key) {
        case .spacer:                   return .header
        case .cutter:                   return .header
        case .cutterWidth:              return .double
        case .cutterHeight:             return .double
        case .cutterDepth:              return .double
        case .labelX1Axis:              return .string
        case .labelY1Axis:              return .string
        case .labelX2Axis:              return .string
        case .labelY2Axis:              return .string
        case .targetFeedSpeed:          return .uint
        case .maxFeedSpeed:             return .uint
        case .feedSpeedCorrection:      return .boolean
        case .fastPretravel:            return .boolean
        case .pretravelSpeed:           return .uint
        case .hotwirePower:             return .uint
        case .hotwirePreheat:           return .uint
        case .gcodeDecimals:            return .uint
        case .block:                    return .header
        case .blockWidth:               return .double
        case .blockHeight:              return .double
        case .blockDepth:               return .double
        case .blockSpacingLeft:         return .double
        case .blockSpacingFront:        return .double
        case .blockSpacingUnder:        return .double
        case .blockRotation:            return .double
        case .shape:                    return .header
        case .shapeWidth:               return .double
        case .shapeSpacingLeft:         return .double
        case .shapeRotation:            return .double
        case .shapeX:                   return .double
        case .shapeY:                   return .double
        case .shapeMirror:              return .boolean
        case .shapeFlip:                return .boolean
        case .chart:                    return .header
        case .showAxisGraph:            return .boolean
        case .showShapeGraph:           return .boolean
        case .showCutterGraph:          return .boolean
        case .showBlockGraph:           return .boolean
        case .showShapeCutGraph:        return .boolean
        default:                        return .none
        }
    }
    
    public func isEditableForKey(_ key: SettingsTableKey) -> Bool {
        switch (key) {
        case .cutterWidth,
             .cutterHeight,
             .cutterDepth,
             .labelX1Axis,
             .labelY1Axis,
             .labelX2Axis,
             .labelY2Axis,
             .gcodeDecimals,
             .targetFeedSpeed,
             .maxFeedSpeed,
             .feedSpeedCorrection,
             .fastPretravel,
             .pretravelSpeed,
             .hotwirePower,
             .hotwirePreheat,
             .blockWidth,
             .blockHeight,
             .blockDepth,
             .blockSpacingLeft,
             .blockSpacingFront,
             .blockSpacingUnder,
             .blockRotation,
             .showAxisGraph,
             .showShapeGraph,
             .showCutterGraph,
             .showBlockGraph,
             .showShapeCutGraph,
             .shapeWidth,
             .shapeSpacingLeft,
             .shapeRotation,
             .shapeX,
             .shapeY,
             .shapeMirror,
             .shapeFlip:
            
            
            
                    return true
        default:    return false
        }
    }
    
    public func labelForKey(_ key: SettingsTableKey) -> String {
        switch (key) {
        case .spacer:                   return ""
        case .cutter:                   return "Machine"
        case .cutterWidth:              return "Operating width [mm]:"
        case .cutterHeight:             return "Operating height [mm]:"
        case .cutterDepth:              return "Operating depth [mm]:"
        case .labelX1Axis:              return "Label left X axis:"
        case .labelY1Axis:              return "Label left Y axis:"
        case .labelX2Axis:              return "Label right X axis:"
        case .labelY2Axis:              return "Label right Y axis:"
        case .gcodeDecimals:            return "# decimals [0...4]:"
        case .targetFeedSpeed:          return "Target feed speed [mm/min]:"
        case .maxFeedSpeed:             return "Maximal feed speed at axis [mm/min]:"
        case .feedSpeedCorrection:      return "Enable feed speed optimization:"
        case .fastPretravel:            return "Enable fast pretraveling:"
        case .pretravelSpeed:           return "Feed speed for pretravel [mm/min]:"
        case .hotwirePower:             return "Power hot wire [%]:"
        case .hotwirePreheat:           return "Pre heat time [s]:"
        case .block:                    return "Foam Block:"
        case .blockWidth:               return "Width [mm]:"
        case .blockHeight:              return "Height [mm]:"
        case .blockDepth:               return "Depth [mm]:"
        case .blockSpacingLeft:         return "Left spacing to machine [mm]:"
        case .blockSpacingFront:        return "Front spacing to machine [mm]:"
        case .blockSpacingUnder:        return "Lower spacing to machine [mm]:"
        case .blockRotation:            return "Rotation around lower left corner [°]:"
        case .shape:                    return "Shape"
        case .shapeWidth:               return "Width [mm]:"
        case .shapeSpacingLeft:         return "Left spacing to machine [mm]:"
        case .shapeRotation:            return "Rotation around lower left corner [°]:"
        case .shapeX:                   return "X movement"
        case .shapeY:                   return "Y movement"
        case .shapeMirror:              return "Mirror the shape:"
        case .shapeFlip:                return "Flip the shape:"
        case .chart:                    return "Show in Graphic"
        case .showAxisGraph:            return "Machine movement:"
        case .showShapeGraph:           return "Shape:"
        case .showCutterGraph:          return "Machine dimension:"
        case .showBlockGraph:           return "Foam dimensions:"
        case .showShapeCutGraph:        return "Shape cutting line:"
        default:           return ""
        }
    }
    public func valueForKey(_ key: SettingsTableKey) -> String {
        switch (key) {
        case .cutterWidth:              return dtos(cutterWidth,            decimals: 0, true)
        case .cutterHeight:             return dtos(cutterHeight,           decimals: 0, true)
        case .cutterDepth:              return dtos(cutterDepth,            decimals: 0, true)
        case .labelX1Axis:              return labelX1Axis
        case .labelY1Axis:              return labelY1Axis
        case .labelX2Axis:              return labelX2Axis
        case .labelY2Axis:              return labelY2Axis
        case .gcodeDecimals:            return String(gcodeDecimals)
        case .targetFeedSpeed:          return String(targetFeedSpeed)
        case .maxFeedSpeed:             return String(maxFeedSpeed)
        case .feedSpeedCorrection:      return btos(feedSpeedCorrection)
        case .fastPretravel:            return btos(fastPretravel)
        case .pretravelSpeed:           return String(pretravelSpeed)
        case .hotwirePower:             return String(hotwirePower)
        case .hotwirePreheat:           return String(hotwirePreheat)
        case .blockWidth:               return dtos(blockWidth,             decimals: 0, true)
        case .blockHeight:              return dtos(blockHeight,            decimals: 0, true)
        case .blockDepth:               return dtos(blockDepth,             decimals: 0, true)
        case .blockSpacingLeft:         return dtos(blockSpacingLeft,       decimals: 0, true)
        case .blockSpacingFront:        return dtos(blockSpacingFront,      decimals: 0, true)
        case .blockSpacingUnder:        return dtos(blockSpacingUnder,      decimals: 0, true)
        case .blockRotation:            return dtos(blockRotation,          decimals: 0, true)
        case .shapeWidth:               return dtos(shapeWidth,             decimals: 0, true)
        case .shapeSpacingLeft:         return dtos(shapeSpacingLeft,       decimals: 0, true)
        case .shapeRotation:            return dtos(shapeRotation,          decimals: 0, true)
        case .shapeX:                   return dtos(shapeX,                 decimals: gcodeDecimals, true)
        case .shapeY:                   return dtos(shapeY,                 decimals: gcodeDecimals, true)
        case .shapeMirror:              return btos(shapeMirror)
        case .shapeFlip:                return btos(shapeFlip)
        case .showAxisGraph:            return btos(showAxisGraph)
        case .showShapeGraph:           return btos(showShapeGraph)
        case .showCutterGraph:          return btos(showCutterGraph)
        case .showBlockGraph:           return btos(showBlockGraph)
        case .showShapeCutGraph:        return btos(showShapeCutGraph)
        default:           return ""
        }
    }
    
    public func isValueValid(_ key: SettingsTableKey, value: String?) -> Bool {
        let value = value ?? ""
        switch (key) {
        case .cutterWidth:              return value.isValidDouble(0, 0)
        case .cutterHeight:             return value.isValidDouble(0, 0)
        case .cutterDepth:              return value.isValidDouble(0, 0)
        case .labelX1Axis:              return value.isValidString(1)
        case .labelY1Axis:              return value.isValidString(1)
        case .labelX2Axis:              return value.isValidString(1)
        case .labelY2Axis:              return value.isValidString(1)
        case .gcodeDecimals:            return value.isValidUInt(0, 4)
        case .targetFeedSpeed:          return value.isValidUInt(0, maxFeedSpeed)
        case .maxFeedSpeed:             return value.isValidUInt(0)
        case .feedSpeedCorrection:      return true // ToDo ggf. prüfung auf 1 und 0
        case .fastPretravel:            return true // ToDo ggf. prüfung auf 1 und 0
        case .pretravelSpeed:           return value.isValidUInt(0)
        case .hotwirePower:             return value.isValidUInt(0, 100)
        case .hotwirePreheat:           return value.isValidUInt(0, 30)
        case .blockWidth:               return value.isValidDouble(0, 0, cutterWidth)
        case .blockHeight:              return value.isValidDouble(0, 0)
        case .blockDepth:               return value.isValidDouble(0, 0)
        case .blockSpacingLeft:         return value.isValidDouble(0, 0, cutterWidth - blockWidth)
        case .blockSpacingFront:        return value.isValidDouble(0, 0)
        case .blockSpacingUnder:        return value.isValidDouble(0, 0)
        case .blockRotation:            return value.isValidDouble(0, -90.0, 90.0)
        case .shapeWidth:               return value.isValidDouble(0, 0, cutterWidth)
        case .shapeSpacingLeft:         return value.isValidDouble(0, 0, cutterWidth - shapeWidth)
        case .shapeRotation:            return value.isValidDouble(0, -90.0, 90.0)
        case .shapeX:                   return value.isValidDouble(gcodeDecimals, -1000.0)
        case .shapeY:                   return value.isValidDouble(gcodeDecimals, -1000.0)
        case .shapeMirror:              return true
        case .shapeFlip:                return true
        case .showAxisGraph:            return true // ToDo ggf. prüfung auf 1 und 0
        case .showShapeGraph:           return true
        case .showCutterGraph:          return true
        case .showBlockGraph:           return true
        case .showShapeCutGraph:        return true
        default: return false
        }
         
    }
    public func valueForKey(_ key: SettingsTableKey, value: String?) {
        switch (key) {
        case .cutterWidth:              self.cutterWidth             = stod(value, true);     break;
        case .cutterHeight:             self.cutterHeight            = stod(value, true);     break;
        case .cutterDepth:              self.cutterDepth             = stod(value, true);     break;
        case .labelX1Axis:              self.labelX1Axis             = value ?? "X";          break;
        case .labelY1Axis:              self.labelY1Axis             = value ?? "Y";          break;
        case .labelX2Axis:              self.labelX1Axis             = value ?? "U";          break;
        case .labelY2Axis:              self.labelY1Axis             = value ?? "Z";          break;
        case .gcodeDecimals:            self.gcodeDecimals           = stoui(value);          break;
        case .targetFeedSpeed:          self.targetFeedSpeed         = stoui(value);          break;
        case .maxFeedSpeed:             self.maxFeedSpeed            = stoui(value);          break;
        case .feedSpeedCorrection:      self.feedSpeedCorrection     = stob(value);           break;
        case .fastPretravel:            self.fastPretravel           = stob(value);           break;
        case .pretravelSpeed:           self.pretravelSpeed          = stoui(value);          break;
        case .hotwirePower:             self.hotwirePower            = stoui(value);          break;
        case .hotwirePreheat:           self.hotwirePreheat          = stoui(value);          break;
        case .blockWidth:               self.blockWidth              = stod(value, true);     break;
        case .blockHeight:              self.blockHeight             = stod(value, true);     break;
        case .blockDepth:               self.blockDepth              = stod(value, true);     break;
        case .blockSpacingLeft:         self.blockSpacingLeft        = stod(value, true);     break;
        case .blockSpacingFront:        self.blockSpacingFront       = stod(value, true);     break;
        case .blockSpacingUnder:        self.blockSpacingUnder       = stod(value, true);     break;
        case .blockRotation:            self.blockRotation           = stod(value, true);     break;
        case .shapeWidth:               self.shapeWidth              = stod(value, true);     break;
        case .shapeSpacingLeft:         self.shapeSpacingLeft        = stod(value, true);     break;
        case .shapeRotation:            self.shapeRotation           = stod(value, true);     break;
        case .shapeX:                   self.shapeX                  = stod(value, true);     break;
        case .shapeY :                  self.shapeY                  = stod(value, true);     break;
        case .shapeMirror:              self.shapeMirror             = stob(value);
                                        mirrorShape();                                        break;
        case .shapeFlip:                self.shapeFlip               = stob(value);
                                        flipShape();                                          break;
        case .showAxisGraph:            self.showAxisGraph           = stob(value);
                                        axisNode.isHidden            = !self.showAxisGraph
                                        return
        case .showShapeGraph:           self.showShapeGraph          = stob(value);
                                        shapeNode.isHidden           = !self.showShapeGraph
                                        return
        case .showCutterGraph:          self.showCutterGraph         = stob(value);
                                        cutterNode.isHidden          = !self.showCutterGraph
                                        return
        case .showBlockGraph:           self.showBlockGraph          = stob(value);
                                        blockNode.isHidden           = !self.showBlockGraph
                                        return
        case .showShapeCutGraph:        self.showShapeCutGraph       = stob(value);
                                        shapeCutNode.isHidden        = !self.showShapeCutGraph
                                        return
        
        default: return
        }
        // neu berechnen und Graph aktualisieren
        _ = calculateShape()
        _ = generateGraph()
    }
   
    func valueFor(_ key: PositionTableKey, index: Int) -> String? {
        if index >= positions.count {
            return nil
        }
        let position = positions[index]
        switch key {
        case .x1Axis:       return dtos(position.x1Axis,     decimals: gcodeDecimals, true)
        case .y1Axis:       return dtos(position.y1Axis,     decimals: gcodeDecimals, true)
        case .x2Axis:       return dtos(position.x2Axis,     decimals: gcodeDecimals, true)
        case .y2Axis:       return dtos(position.y2Axis,     decimals: gcodeDecimals, true)
        case .x1Shape:      return dtos(position.x1Shape,    decimals: gcodeDecimals, true)
        case .y1Shape:      return dtos(position.y1Shape,    decimals: gcodeDecimals, true)
        case .w1Shape:      return dtos(position.w1Shape,    decimals: gcodeDecimals, true)
        case .x2Shape:      return dtos(position.x2Shape,    decimals: gcodeDecimals, true)
        case .y2Shape:      return dtos(position.y2Shape,    decimals: gcodeDecimals, true)
        case .w2Shape:      return dtos(position.w2Shape,    decimals: gcodeDecimals, true)
        case .x1Block:      return dtos(position.x1Block,    decimals: gcodeDecimals, true)
        case .y1Block:      return dtos(position.y1Block,    decimals: gcodeDecimals, true)
        case .w1Block:      return dtos(position.w1Block,    decimals: gcodeDecimals, true)
        case .x2Block:      return dtos(position.x2Block,    decimals: gcodeDecimals, true)
        case .y2Block:      return dtos(position.y2Block,    decimals: gcodeDecimals, true)
        case .w2Block:      return dtos(position.w2Block,    decimals: gcodeDecimals, true)
        case .hotwire:
            if position.hotwire {
                return "1"
            } else {
                return nil
            }
        case .pretravel:
            if position.pretravel {
                return "1"
            } else {
                return nil
            }
        default:
            return nil
        }
    }
    
    func isValueValid(_ key: PositionTableKey, index: Int, value: String?) -> Bool {
        let value = value ?? ""
        switch key {
        case .x1Axis, .y1Axis, .x2Axis, .y2Axis, .x1Block, .y1Block, .w1Block, .x2Block, .y2Block, .w2Block, .x1Shape, .y1Shape, .w1Shape, .x2Shape, .y2Shape, .w2Shape:
            return value.isValidDouble(gcodeDecimals)
        case .hotwire, .pretravel:
            return true
        default: return false
        }
    }
    

    func valueFor(_ key: PositionTableKey, index: Int, value: String?) {
        if index >= positions.count {
            return
        }
        guard let value = value else {
            return
        }
        var key = key
        let position = positions[index]
        
        switch key {
        case .x1Axis:   position.x1Axis     = stod(value, true);        break
        case .y1Axis:   position.y1Axis     = stod(value, true);        break
        case .x2Axis:   position.x2Axis     = stod(value, true);        break
        case .y2Axis:   position.y2Axis     = stod(value, true);        break
        case .x1Shape:  position.x1Shape    = stod(value, true);        break
        case .y1Shape:  position.y1Shape    = stod(value, true);        break
        case .w1Shape:  position.w1Shape    = stod(value, true);        break
        case .x2Shape:  position.x1Shape    = stod(value, true);        break
        case .y2Shape:  position.y2Shape    = stod(value, true);        break
        case .w2Shape:  position.w2Shape    = stod(value, true);        break
        case .x1Block:  position.x1Block    = stod(value, true);        break
        case .y1Block:  position.y1Block    = stod(value, true);        break
        case .w1Block:  position.w1Block    = stod(value, true);        break
        case .x2Block:  position.x2Block    = stod(value, true);        break
        case .y2Block:  position.y2Block    = stod(value, true);        break
        case .w2Block:  position.w2Block    = stod(value, true);        break
    
        case .hotwire:
            if value == "1" {
                position.hotwire = true
            } else {
                position.hotwire = false
            }
            key = .x1Block
        case .pretravel:
            if value == "1" {
                position.pretravel = true
            } else {
                position.pretravel = false
            }
            key = .x1Block
        default:
            return
        }
        calculatePosition(position, source: key)
        requestUpdatePositionsTable(index)
        _ = generateGraph()
        
        return
    }
    
    
    func deleteIndex(_ index: Int) {
        guard index < positions.count else {
            return
        }
        positions.remove(at: index)
        // neu berechnen und Graph aktualisieren
        _ = calculateShape()
        _ = generateGraph()
        return
    }
    func addIndex(_ index: Int) {
        guard positions.count > 0 else {
            return
        }
        
        var p1: CuttingPosition
        var p2: CuttingPosition
        
        if index < positions.count {
            p2 = positions[index]
        } else {
            p2 = positions.last!
        }
        
        if index > 0 {
            p1 = positions[index-1]
        } else {
            p1 = positions.first!
        }
        
        let p = CuttingPosition()
        p.x1Shape     =  (p2.x1Shape + p1.x1Shape) / 2
        p.y1Shape     =  (p2.y1Shape + p1.y1Shape) / 2
        p.w1Shape     =  (p2.w1Shape + p1.w1Shape) / 2
        p.x2Shape     =  (p2.x2Shape + p1.x2Shape) / 2
        p.y2Shape     =  (p2.y2Shape + p1.y2Shape) / 2
        p.w2Shape     =  (p2.w2Shape + p1.w2Shape) / 2
        
        if index < positions.count {
            positions.insert(p, at: index)
        } else {
            positions.append(p)
        }
        
        // neu berechnen und Graph aktualisieren
        _ = calculateShape()
        _ = generateGraph()
        return
    }
    private func generateCutterNode(depth:        Double,
                                    height:       Double,
                                    width:        Double,
                                    color:        NSColor,
                                    edgeColor:    NSColor,
                                    diameter:     Double    = 2.0) -> SCNNode {
           
        var plane:      SCNPlane
        var planeNode:  SCNNode
        
        let node        = SCNNode()
        let color       = color.withAlphaComponent(0.5)
        
        plane           = SCNPlane(width: CGFloat(depth),
                                   height: CGFloat(height))
        plane.firstMaterial?.diffuse.contents   = color
        plane.firstMaterial?.isDoubleSided      = true
        planeNode                               = SCNNode(geometry:plane)
        planeNode.eulerAngles.y                 = .pi / 2
        planeNode.position.x                    = CGFloat(width)        * (-0.5)
        node.addChildNode(planeNode)
        
        planeNode                               = planeNode.clone()
        planeNode.position.x                    = CGFloat(width)        * (0.5)
        node.addChildNode(planeNode)
        
        node.pivot                              = SCNMatrix4MakeTranslation(CGFloat(-width)/2.0, CGFloat(-height)/2.0, CGFloat(depth)/2.0);
        
        return node
    }
    
               
    private func generateShapeNode() -> SCNNode {
        let node        = SCNNode()
        
        for position in positions {
            var color = shapeColor
            if position.hotwire {
                color = shapeColorHotwire
            }
            node.addChildNode(drawLine(x1: position.x1Block,
                                       y1: position.y1Block,
                                       w1: position.w1Block,
                                       x2: position.x2Block,
                                       y2: position.y2Block,
                                       w2: position.w2Block,
                                       color: color))
        }
        return node
    }
    private func generateShapeCutNode() -> SCNNode {
        let node        = SCNNode()
        var first       = true
        var x:          Double = 0.0
        var y:          Double = 0.0
        var w:          Double = 0.0
        
        for position in positions {
            if first {
                first = false
                x = position.x1Block
                y = position.y1Block
                w = position.w1Block
            } else {
                var color = shapeColor
                if position.hotwire {
                    color = shapeColorHotwire
                }
                node.addChildNode(drawLine(x1: x,
                                           y1: y,
                                           w1: w,
                                           x2: position.x1Block,
                                           y2: position.y1Block,
                                           w2: position.w1Block,
                                           color: color))
                x = position.x1Block
                y = position.y1Block
                w = position.w1Block
            }
        }
        
        first       = true
        for position in positions {
            if first {
                first = false
                x = position.x2Block
                y = position.y2Block
                w = position.w2Block
            } else {
                var color = shapeColor
                if position.hotwire {
                    color = shapeColorHotwire
                }
                node.addChildNode(drawLine(x1: x,
                                           y1: y,
                                           w1: w,
                                           x2: position.x2Block,
                                           y2: position.y2Block,
                                           w2: position.w2Block,
                                           color: color))
                x = position.x2Block
                y = position.y2Block
                w = position.w2Block
            }
        }
        
        
        return node
       
    }
    private func updateWireNode()  {
        wireNode.removeFromParentNode()
        wireNode    = SCNNode()
        
        guard let markedPosition = markedPosition else {
            return
        }
        if markedPosition >= positions.count {
            self.markedPosition = nil
            return
        }
        let position = positions[markedPosition]
        
        
        //SCNTransaction.begin()
       // SCNTransaction.animationDuration = 0.5
        wireNode.addChildNode(drawLine(x1: position.x1Axis,
                                       y1: position.y1Axis,
                                       w1: 0.0,
                                       x2: position.x2Axis,
                                       y2: position.y2Axis,
                                       w2: cutterWidth,
                                       color: wireColor))
        previewNode.addChildNode(wireNode)
        
        
      //  SCNTransaction.commit()
        
    }
    private func generateAxisNode() -> SCNNode {
        let node        = SCNNode()
        var first       = true
        var x:          Double = 0.0
        var y:          Double = 0.0
        
        for position in positions {
            if first {
                first = false
                x = position.x1Axis
                y = position.y1Axis
            } else {
                var color = axisColor
                if position.hotwire {
                    color = axisColorHotwire
                }
                if (position.x1Axis < 0) || (position.y1Axis < 0) || (position.x1Axis > cutterDepth) || (position.y1Axis > cutterHeight) ||
                   (x < 0) || (y < 0) || (x > cutterDepth) || (y > cutterHeight) {
                    color = axisColorAlert
                }

                node.addChildNode(drawLine(x1: x,
                                           y1: y,
                                           w1: 0.0,
                                           x2: position.x1Axis,
                                           y2: position.y1Axis,
                                           w2: 0.0,
                                           color: color))
                x = position.x1Axis
                y = position.y1Axis
            }
        }
        
        first       = true
        for position in positions {
            if first {
                first = false
                x = position.x2Axis
                y = position.y2Axis
            } else {
                var color = axisColor
                if position.hotwire {
                    color = axisColorHotwire
                }
                if (position.x2Axis < 0) || (position.y2Axis < 0) || (position.x2Axis > cutterDepth) || (position.y2Axis > cutterHeight) ||
                   (x < 0) || (y < 0) || (x > cutterDepth) || (y > cutterHeight) {
                    color = axisColorAlert
                }

                node.addChildNode(drawLine(x1: x,
                                           y1: y,
                                           w1: cutterWidth,
                                           x2: position.x2Axis,
                                           y2: position.y2Axis,
                                           w2: cutterWidth,
                                           color: color))
                x = position.x2Axis
                y = position.y2Axis
            }
        }
        
        
        return node
       
    }

    private func drawLine(x1:       Double,
                          y1:       Double,
                          w1:       Double,
                          x2:       Double,
                          y2:       Double,
                          w2:       Double,
                          color:    NSColor,
                          diameter: Double    = 2.0) -> SCNNode {

        let p1 = SCNVector3Make(CGFloat(w1), CGFloat(y1), CGFloat(-x1))
        let p2 = SCNVector3Make(CGFloat(w2), CGFloat(y2), CGFloat(-x2))
        
        let vector                  = SCNVector3(p1.x - p2.x, p1.y - p2.y, p1.z - p2.z)
        let distance                = sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
        let midPosition             = SCNVector3 (x:(p1.x + p2.x) / 2, y:(p1.y + p2.y) / 2, z:(p1.z + p2.z) / 2)

        let lineGeometry            = SCNCapsule()
        lineGeometry.capRadius      = CGFloat(diameter/2)
        lineGeometry.height         = distance + CGFloat(diameter)
               
        lineGeometry.radialSegmentCount = 12
        lineGeometry.firstMaterial!.diffuse.contents = color

        let lineNode = SCNNode(geometry: lineGeometry)
        lineNode.position = midPosition
        lineNode.look (at: p2, up: previewNode.worldUp, localFront: lineNode.worldUp)
        
        return lineNode
    }
    
   
    private func generateFoamBlockeNode(x:            Double,
                                        y:            Double,
                                        w:            Double,
                                        depth:        Double,
                                        height:       Double,
                                        width:        Double,
                                        rotationX:    Double    = 0.0,
                                        rotationY:    Double    = 0.0,
                                        rotationW:    Double    = 0.0,
                                        color:        NSColor,
                                        edgeColor:    NSColor,
                                        diameter:     Double    = 2.0) -> SCNNode {
        
        var h:          CGFloat
        var edge:       SCNCapsule
        var edgeNode:   SCNNode
        let node        = SCNNode()
        let color       = color.withAlphaComponent(0.5)
        
        // draw the box
        let box         = SCNBox(width: CGFloat(width),
                                 height: CGFloat(height),
                                 length: CGFloat(depth),
                                 chamferRadius: CGFloat(diameter/2))
        box.firstMaterial?.diffuse.contents = color
        node.addChildNode(SCNNode(geometry: box))
        
        // long edges
        h                                       = CGFloat(width)
        edge                                    = SCNCapsule(capRadius: CGFloat(diameter/2), height: h)
        edge.radialSegmentCount                 = 12
        edge.firstMaterial?.diffuse.contents    = edgeColor
        edgeNode                                = SCNNode(geometry: edge)
        edgeNode.position.y                     = CGFloat(height - diameter)        * (-0.5)
        edgeNode.position.z                     = CGFloat(depth - diameter)         * (-0.5)
        edgeNode.eulerAngles.x                  = .pi / 2
        edgeNode.eulerAngles.y                  = .pi / 2
        node.addChildNode(edgeNode)
        
        edgeNode                                = edgeNode.clone()
        edgeNode.position.y                     = CGFloat(height - diameter)        * (-0.5)
        edgeNode.position.z                     = CGFloat(depth - diameter)         * (0.5)
        node.addChildNode(edgeNode)
        
        edgeNode                                = edgeNode.clone()
        edgeNode.position.y                     = CGFloat(height - diameter)        * (0.5)
        edgeNode.position.z                     = CGFloat(depth - diameter)         * (-0.5)
        node.addChildNode(edgeNode)
        
        edgeNode                                = edgeNode.clone()
        edgeNode.position.y                     = CGFloat(height - diameter)        * (0.5)
        edgeNode.position.z                     = CGFloat(depth - diameter)         * (0.5)
        node.addChildNode(edgeNode)
        
        // short edges
        h                                       = CGFloat(height)
        edge                                    = SCNCapsule(capRadius: CGFloat(diameter/2), height: h)
        edge.radialSegmentCount                 = 12
        edge.firstMaterial?.diffuse.contents    = edgeColor
        edgeNode                                = SCNNode(geometry: edge)
        edgeNode.eulerAngles.y                  = .pi / 2
        edgeNode.position.z                     = CGFloat(depth - diameter)         * (-0.5)
        edgeNode.position.x                     = CGFloat(width - diameter)         * (-0.5)
        node.addChildNode(edgeNode)
        
        edgeNode                                = edgeNode.clone()
        edgeNode.position.z                     = CGFloat(depth - diameter)         * (0.5)
        edgeNode.position.x                     = CGFloat(width - diameter)         * (-0.5)
        node.addChildNode(edgeNode)
        
        edgeNode                                = edgeNode.clone()
        edgeNode.position.z                     = CGFloat(depth - diameter)         * (-0.5)
        edgeNode.position.x                     = CGFloat(width - diameter)         * (0.5)
        node.addChildNode(edgeNode)
        
        edgeNode                                = edgeNode.clone()
        edgeNode.position.z                     = CGFloat(depth - diameter)         * (0.5)
        edgeNode.position.x                     = CGFloat(width - diameter)         * (0.5)
        node.addChildNode(edgeNode)
        
        h                                       = CGFloat(depth)
        edge                                    = SCNCapsule(capRadius: CGFloat(diameter/2), height: h)
        edge.radialSegmentCount                 = 12
        edge.firstMaterial?.diffuse.contents    = edgeColor
        edgeNode                                = SCNNode(geometry: edge)
        edgeNode.eulerAngles.x                  = .pi / 2
        edgeNode.position.x                     = CGFloat(width - diameter)         * (-0.5)
        edgeNode.position.y                     = CGFloat(height - diameter)        * (-0.5)
        node.addChildNode(edgeNode)
        
        edgeNode                                = edgeNode.clone()
        edgeNode.position.x                     = CGFloat(width - diameter)         * (0.5)
        edgeNode.position.y                     = CGFloat(height - diameter)        * (-0.5)
        node.addChildNode(edgeNode)
        
        edgeNode                                = edgeNode.clone()
        edgeNode.position.x                     = CGFloat(width - diameter)         * (-0.5)
        edgeNode.position.y                     = CGFloat(height - diameter)        * (0.5)
        node.addChildNode(edgeNode)
        
        edgeNode                                = edgeNode.clone()
        edgeNode.position.x                     = CGFloat(width - diameter)         * (0.5)
        edgeNode.position.y                     = CGFloat(height - diameter)        * (0.5)
        node.addChildNode(edgeNode)
        
        node.pivot                              = SCNMatrix4MakeTranslation(CGFloat(-width)/2.0, CGFloat(-height)/2.0, CGFloat(depth)/2.0);
        node.eulerAngles.y                      = CGFloat(rotationY / 180.0 * .pi)
        node.eulerAngles.z                      = CGFloat(rotationX / 180.0 * .pi)
        node.eulerAngles.x                      = CGFloat(-rotationW / 180.0 * .pi)
        
        node.position.y                         = CGFloat(y)
        node.position.z                         = CGFloat(-x)
        node.position.x                         = CGFloat(w)
        
        
        return node
    }
}



extension String {

    public func isValidUInt(_ min: UInt? = nil, _ max: UInt? = nil) -> Bool {
        if self == "" {
            return true
        }
        guard self.count > 0 else  {
            return false
        }
            
        let nums: Set<Character> = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
        if Set(self).isSubset(of: nums) == false {
            return false
        }
        if let value = Int(self) {
            if let min = min {
                if value < min {
                    return false
                }
            }
            if let max = max {
                if value > max {
                    return false
                }
            }
        }
        return true
    }
    public func isValidString(_ length: Int) -> Bool {
        if self == "" {
            return true
        }
        guard self.count > 0 else  {
            return false
        }
        if self.count > length {
            return false
        }
        return true
    }
    public func appearance(_ char: Character) -> Int {
        return self.filter { $0 == char }.count // case-sensitive
    }
    
    public func isValidDouble( _ decimals: UInt, _ min: Double?  = nil, _ max: Double? = nil) -> Bool {
        if self == "" {
            return true
        }
        guard self.count > 0 else  {
            return false
        }
        
        // m: Anzahl der Zahlen gesamt
        // d: Anzahl der Zahlen hinter dem Komma
        var string: String  = self
        var ms: String?     = nil
        var ds: String?     = nil
        
        var nums: Set<Character> = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
        if let min = min, min < 0 {
            nums.insert("-")
        }
        if decimals > 0 {
            nums.insert(Character("Komma".localized()))
        }
        
        if Set(string).isSubset(of: nums) == false {
            // ungültiges Zeichen eingegeben >> raus
            return false
        }
        string = string.replacingOccurrences(of: ",", with: "Komma".localized())
        string = string.replacingOccurrences(of: ".", with: "Komma".localized())
        // Maximal ein Komma im String zulässig
        if string.appearance(Character("Komma".localized())) > 1 {
            return false
        }
        // prüfe ob das erste Zeichen ein "-" ist
        if string.first == "-" {
            string = String(string.dropFirst())
        }
        

        // prüfe ob ein "." oder "," vorhanden ist
        if  string.contains("Komma".localized()) {
            // es ist ein Komma enthalten
            // prüfe ob das erste Zeichen ein . ist
            if string.first == Character("Komma".localized()) {
                ds = String(string.dropFirst())
                // prüfe ob weitere . vorhanden sind
                if ds?.contains("Komma".localized()) ?? false {
                    return false
                }
            } else {
                // trenne nach Komma auf
                let lines = string.components(separatedBy: "Komma".localized()).filter{ !$0.isEmpty }
                if lines.count > 2 {
                    return false
                }
                ms = lines.first
                if lines.count == 2 {
                    ds = lines.last
                }
            }
        } else {
            ms = string
        }
        
        nums = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
        if let ds = ds {
            if ds.count > decimals || Set(ds).isSubset(of: nums) == false {
                return false
            }
        }
        if let ms = ms {
            if Set(ms).isSubset(of: nums) == false {
                return false
            }
            // prüfe ob mehr als eine führende 0 vorhanden ist
            if ms.first == "0" {
                if String(string.dropFirst()).first == "0" {
                    return false
                }
            }
        }
        
        if let dvalue = Double(self) {
            if let min = min {
                if dvalue < min {
                    return false
                }
            }
            if let max = max {
                if dvalue > max {
                    return false
                }
            }
        }
        return true
    }
    

}



extension Color {

    func cgColor() -> CGColor {

        let components = self.components()
        return CGColor(red: components.r, green: components.g, blue: components.b, alpha: components.a)
    }
    func nsColor() -> NSColor {

        let components = self.components()
        return NSColor(red: components.r, green: components.g, blue: components.b, alpha: components.a)
    }

    private func components() -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {

        let scanner = Scanner(string: self.description.trimmingCharacters(in: CharacterSet.alphanumerics.inverted))
        var hexNumber: UInt64 = 0
        var r: CGFloat = 0.0, g: CGFloat = 0.0, b: CGFloat = 0.0, a: CGFloat = 0.0

        let result = scanner.scanHexInt64(&hexNumber)
        if result {
            r = CGFloat((hexNumber & 0xff000000) >> 24) / 255
            g = CGFloat((hexNumber & 0x00ff0000) >> 16) / 255
            b = CGFloat((hexNumber & 0x0000ff00) >> 8) / 255
            a = CGFloat(hexNumber & 0x000000ff) / 255
        }
        return (r, g, b, a)
    }
}
