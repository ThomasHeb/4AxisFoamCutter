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
// - generate a new file
//   newFile() -> Int                           =  0 if ok
//                                             != 0 if not ok
//
// - load a file (fcf), including settings,....
//   loadFromFile(_ file: String?) -> Int      =  0 if ok
//                                             != 0 if not ok
//
// - save a file (fcf), including settings,....
//   saveToFile(_ file: String?) -> Int        =  0 if ok
//                                             != 0 if not ok
//
// - import a file, old content is keept for merging (only merged content can be saved)
//   Supported filetypes
//   gcode, nc: simple gcode wit G00/G0, G01, G1, G90, G91, ...
//   how: Winghelper ICE export with absolute coordinates
//   fcf: Foam Cuter File previously saved
//   importShapeFromFile(_ file: String?) -> Int      =  0 if ok
//                                                    != 0 if not ok
//
// - merge content of two placements into one. rotation and x/z movement is discarded, only spacing is kept
//   merge() -> Int                            =  0 if ok
//                                             != 0 if not ok
// - discard content, if content is kept for merging
//   discard() -> Int                          =  0 if ok
//                                             != 0 if not ok
//
// - export a file in gcode format
//   exportGCodeToFile(_ file: String?) -> Int        =  0 if ok
//                                                    != 0 if not ok
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
// - Callbacks (FCalcMenuCallback):
//
// - Preview:
//   A preveiw Scene Kit Node (SCNNode) is generated and updated with the updatePreview-Callback.
//   If the node is linked once to the scene, no further actions are required (please do not relink the node to the scene.
//   You can change the camera position with setCamera(_ direction: cameraDirection), 
//   if allowsCameraControl is enabled for SCNView, you need to delete the user camera before calling setCamera. Do this by
//   setting yourSCNView.pointOfView = nil.
//   Functions:
//   - play()
//   - playPause()
//   - pause()
//   - stop()
//
///
// ============================================================================================================================
// HoC
//
// 2020-07-22   General:    First release and upload to github
// 2020-07-24   General:    Store/load settings from registry
//              Preview:    Set camera to predefined poitions
//              General:    Import/export functions renamed
//              General:    Restructured Programm FCalc to App
//              Parameter:  Simulation speed factor added
//              Parameter:  Restructured in codable struct for load/save with json
//              General:    Load/save/new added
//              General:    Import and load allows a merge
//              General:    Merging of two shapes / Discard of merge
// 2020-08-18   Shape:      Reverse shape added
//              General:    Merging after/before added
//              Preview:    Diameter of cutting lines as parameter
//              General:    Load optimized to use optional json decoding, to be compatible if value is not stored
//              General:    Handling of projectName optimized), callback if changed
//              General:    Statustext is generated and passed via callback
//              General:    horizontal/vertiacal mirroring added
//              General:    Error in travel speed with disabled speed optimization solved
//              General:    in case of speed calculation less then target speed, taget speed is used
//              General:    added comment for hotwire setting and foam material
// 2020-08-24   Import:     Error on z-Axis for relativ import removed
//              Import:     Added additional gcode commands for import (read and ignored G17, G....)
//              Import:     order of read for one or two digit commands optimized
//              Preview:    reworked all update functions to improve speed for SCNNode update
//                          Only relevant nodes are removed or recalculated
//              General:    Rotating shape around w axis

protocol FCalcCallback {
    func updatePositionsTableView(_ atIndex: Int?)
    func updatePreview(_ node: SCNNode)
    func updateSettingsTableView()
    func updateProjectName(_ projectName: String?)
    func updateStatusText(_ statusText: String?)
}


class FCalc {
    public var callback:        FCalcCallback?                              = nil
     
    
    public enum cameraDirection: Int {
        case front
        case top
        case left
        case right
        case home
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
        case hotwireSettingComment
  
        case block
        case blockMaterialComment
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
        case shapeRotationY
        case shapeRotationW
        case shapeX
        case shapeY
        case shapeChangeAxis
        case shapeMirrorHorizontal
        case shapeMirrorVertical
        case shapeReverse
        
        case preview
        case showCutterGraph
        case showAxisGraph
        case showBlockGraph
        case showShapeGraph
        case showShapeCutGraph
        case simulationSpeed
        case previewDiameter
        
        var description : String {                          // String IDs for storing in Registry
            switch self {
            case .none:                     return "0"      // this must keept to 0 to check if values are stored
            case .spacer:                   return "1"
            case .cutter:                   return "2"
            case .cutterWidth:              return "3"
            case .cutterHeight:             return "4"
            case .cutterDepth:              return "5"
            case .labelX1Axis:              return "6"
            case .labelY1Axis:              return "7"
            case .labelX2Axis:              return "8"
            case .labelY2Axis:              return "9"
            case .gcodeDecimals:            return "10"
            case .targetFeedSpeed:          return "11"
            case .feedSpeedCorrection:      return "12"
            case .maxFeedSpeed:             return "13"
            case .fastPretravel:            return "14"
            case .pretravelSpeed:           return "15"
            case .hotwirePower:             return "16"
            case .hotwirePreheat:           return "17"
            
            case .block:                    return "18"
            case .blockWidth:               return "19"
            case .blockHeight:              return "20"
            case .blockDepth:               return "21"
            case .blockSpacingLeft:         return "22"
            case .blockSpacingFront:        return "23"
            case .blockSpacingUnder:        return "24"
            case .blockRotation:            return "25"
                  
            case .shape:                    return "26"
            case .shapeWidth:               return "27"
            case .shapeSpacingLeft:         return "28"
            case .shapeRotationY:           return "29"
            case .shapeX:                   return "30"
            case .shapeY:                   return "31"
            case .shapeChangeAxis:          return "32"
            case .shapeMirrorHorizontal:    return "33"
                  
            case .preview:                  return "34"
            case .showCutterGraph:          return "35"
            case .showAxisGraph:            return "36"
            case .showBlockGraph:           return "37"
            case .showShapeGraph:           return "38"
            case .showShapeCutGraph:        return "39"
                
            case .simulationSpeed:          return "40"
            case .shapeReverse:             return "41"
            case .previewDiameter:          return "42"
            case .shapeMirrorVertical:      return "43"
                
            case .hotwireSettingComment:    return "44"
            case .blockMaterialComment:     return "45"
            case .shapeRotationW:           return "46"
            }
        }
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
    
    
    private let storeInReg:       [FCalc.SettingsTableKey]     =
        [ .cutterWidth,
          .cutterHeight,
          .cutterDepth,
          .labelX1Axis,
          .labelY1Axis,
          .labelX2Axis,
          .labelY2Axis,
          .gcodeDecimals,
          .targetFeedSpeed,
          .feedSpeedCorrection,
          .maxFeedSpeed,
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
          
          .shapeWidth,
          .shapeSpacingLeft,
          //.shapeRotationY,
          //.shapeRotationW,
          //.shapeX,
          //.shapeY,
          //.shapeChangeAxis,
          //.shapeMirrorHorizontal,
          //.shapeMirrorVertical,
          //.shapeReverse,
            
          .showCutterGraph,
          .showAxisGraph,
          .showBlockGraph,
          .showShapeGraph,
          .showShapeCutGraph,
            
          .simulationSpeed,
          .previewDiameter,
          
          .hotwireSettingComment,
          .blockMaterialComment
            
        ]
      
    private(set) var    projectName:              String?                 = nil {
        didSet {
            if let f = callback?.updateProjectName(_:) {
                f(self.projectName)
            }
        }
    }
    private var         file:                     String?                 = nil
    private(set) var    allowedImportFileTypes                            = ["how","gcode", "nc", "fcf"]
    private(set) var    allowedLoadFileTypes                              = ["fcf"]
    
    private class FCalcData: Codable {
        // Achsenlabels für GCode export
        var         labelX1Axis:                String                  = "X"
        var         labelY1Axis:                String                  = "Y"
        var         labelX2Axis:                String                  = "U"
        var         labelY2Axis:                String                  = "Z"
        var         gcodeDecimals:              UInt                    = 2
        // Cutter Dimension
        var         cutterWidth:                Double                  = 721.0
        var         cutterHeight:               Double                  = 220.0
        var         cutterDepth:                Double                  = 350.0
         // Foam Block Dimensions
        var         blockWidth:                 Double                  = 500.0
        var         blockHeight:                Double                  = 100.0
        var         blockDepth:                 Double                  = 100.0
        // Foam Block Position
        var         blockSpacingLeft:           Double                  = 100.0
        var         blockSpacingFront:          Double                  = 0.0
        var         blockSpacingUnder:          Double                  = 0.0
        var         blockRotation:              Double                  = 0.0
        var         blockMaterialComment:       String                  = ""
        // Shape Position Correction
        var         shapeWidth:                 Double                  = 500.0
        var         shapeSpacingLeft:           Double                  = 100.0
        var         shapeRotationY:             Double                  = 0.0
        var         shapeRotationW:             Double                  = 0.0
        var         shapeX:                     Double                  = 0.0
        var         shapeY:                     Double                  = 0.0
        var         shapeChangeAxis:            Bool                    = false
        var         shapeMirrorHorizontal:      Bool                    = false
        var         shapeMirrorVertical:        Bool                    = false
        var         shapeReverse:               Bool                    = false
        // Hotwire and Speed Adjustment
        var         targetFeedSpeed:            UInt                    = 300   // mm/min
        var         feedSpeedCorrection:        Bool                    = true
        var         maxFeedSpeed:               UInt                    = 1500  // mm/min
        var         hotwirePower:               UInt                    = 90    // in %
        var         hotwirePreheat:             UInt                    = 5
        var         fastPretravel:              Bool                    = true
        var         pretravelSpeed:             UInt                    = 1000  // mm/min
        var         hotwireSettingComment:      String                  = ""
        
        var         positions:                  [CuttingPosition]       = Array()
        
        public func copy() -> FCalcData {
            let new                     = FCalcData()
            new.labelX1Axis             = self.labelX1Axis
            new.labelY1Axis             = self.labelY1Axis
            new.labelX2Axis             = self.labelX2Axis
            new.labelY2Axis             = self.labelY2Axis
            new.gcodeDecimals           = self.gcodeDecimals
            new.cutterWidth             = self.cutterWidth
            new.cutterHeight            = self.cutterHeight
            new.cutterDepth             = self.cutterDepth
            new.blockWidth              = self.blockWidth
            new.blockHeight             = self.blockHeight
            new.blockDepth              = self.blockDepth
            new.blockSpacingLeft        = self.blockSpacingLeft
            new.blockSpacingFront       = self.blockSpacingFront
            new.blockSpacingUnder       = self.blockSpacingUnder
            new.blockRotation           = self.blockRotation
            new.blockMaterialComment    = self.blockMaterialComment
            new.shapeWidth              = self.shapeWidth
            new.shapeSpacingLeft        = self.shapeSpacingLeft
            new.shapeRotationY          = self.shapeRotationY
            new.shapeRotationW          = self.shapeRotationW
            new.shapeX                  = self.shapeX
            new.shapeY                  = self.shapeY
            new.shapeChangeAxis         = self.shapeChangeAxis
            new.shapeMirrorHorizontal   = self.shapeMirrorHorizontal
            new.shapeMirrorVertical     = self.shapeMirrorVertical
            new.shapeReverse            = self.shapeReverse
            new.targetFeedSpeed         = self.targetFeedSpeed
            new.feedSpeedCorrection     = self.feedSpeedCorrection
            new.maxFeedSpeed            = self.maxFeedSpeed
            new.hotwirePower            = self.hotwirePower
            new.hotwirePreheat          = self.hotwirePreheat
            new.fastPretravel           = self.fastPretravel
            new.pretravelSpeed          = self.pretravelSpeed
            new.hotwireSettingComment   = self.hotwireSettingComment
            new.positions               = self.positions
            
            return new
        }
        init() {
            
        }
        required init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
    
            if let v = try container.decodeIfPresent(String.self, forKey: .labelX1Axis)         {   self.labelX1Axis            = v    }
            if let v = try container.decodeIfPresent(String.self, forKey: .labelY1Axis)         {   self.labelY1Axis            = v    }
            if let v = try container.decodeIfPresent(String.self, forKey: .labelX2Axis)         {   self.labelX2Axis            = v    }
            if let v = try container.decodeIfPresent(String.self, forKey: .labelY2Axis)         {   self.labelY2Axis            = v    }
            if let v = try container.decodeIfPresent(UInt.self, forKey: .gcodeDecimals)         {   self.gcodeDecimals          = v    }
            if let v = try container.decodeIfPresent(Double.self, forKey: .cutterWidth)         {   self.cutterWidth            = v    }
            if let v = try container.decodeIfPresent(Double.self, forKey: .cutterHeight)        {   self.cutterHeight           = v    }
            if let v = try container.decodeIfPresent(Double.self, forKey: .cutterDepth)         {   self.cutterDepth            = v    }
            if let v = try container.decodeIfPresent(Double.self, forKey: .blockWidth)          {   self.blockWidth             = v    }
            if let v = try container.decodeIfPresent(Double.self, forKey: .blockHeight)         {   self.blockHeight            = v    }
            if let v = try container.decodeIfPresent(Double.self, forKey: .blockDepth)          {   self.blockDepth             = v    }
            if let v = try container.decodeIfPresent(Double.self, forKey: .blockSpacingLeft)    {   self.blockSpacingLeft       = v    }
            if let v = try container.decodeIfPresent(Double.self, forKey: .blockSpacingFront)   {   self.blockSpacingFront      = v    }
            if let v = try container.decodeIfPresent(Double.self, forKey: .blockSpacingUnder)   {   self.blockSpacingUnder      = v    }
            if let v = try container.decodeIfPresent(Double.self, forKey: .blockRotation)       {   self.blockRotation          = v    }
            if let v = try container.decodeIfPresent(String.self, forKey: .blockMaterialComment){   self.blockMaterialComment   = v    }
            if let v = try container.decodeIfPresent(Double.self, forKey: .shapeWidth)          {   self.shapeWidth             = v    }
            if let v = try container.decodeIfPresent(Double.self, forKey: .shapeSpacingLeft)    {   self.shapeSpacingLeft       = v    }
            if let v = try container.decodeIfPresent(Double.self, forKey: .shapeRotationY)      {   self.shapeRotationY         = v    }
            if let v = try container.decodeIfPresent(Double.self, forKey: .shapeRotationW)      {   self.shapeRotationW         = v    }
            if let v = try container.decodeIfPresent(Double.self, forKey: .shapeX)              {   self.shapeX                 = v    }
            if let v = try container.decodeIfPresent(Double.self, forKey: .shapeY)              {   self.shapeY                 = v    }
            if let v = try container.decodeIfPresent(Bool.self, forKey: .shapeChangeAxis)       {   self.shapeChangeAxis        = v    }
            if let v = try container.decodeIfPresent(Bool.self, forKey: .shapeMirrorHorizontal) {   self.shapeMirrorHorizontal  = v    }
            if let v = try container.decodeIfPresent(Bool.self, forKey: .shapeMirrorVertical)   {   self.shapeMirrorVertical    = v    }
            if let v = try container.decodeIfPresent(Bool.self, forKey: .shapeReverse)          {   self.shapeReverse           = v    }
            if let v = try container.decodeIfPresent(UInt.self, forKey: .targetFeedSpeed)       {   self.targetFeedSpeed        = v    }
            if let v = try container.decodeIfPresent(Bool.self, forKey: .feedSpeedCorrection)   {   self.feedSpeedCorrection    = v    }
            if let v = try container.decodeIfPresent(UInt.self, forKey: .maxFeedSpeed)          {   self.maxFeedSpeed           = v    }
            if let v = try container.decodeIfPresent(UInt.self, forKey: .hotwirePower)          {   self.hotwirePower           = v    }
            if let v = try container.decodeIfPresent(UInt.self, forKey: .hotwirePreheat)        {   self.hotwirePreheat         = v    }
            if let v = try container.decodeIfPresent(Bool.self, forKey: .fastPretravel)         {   self.fastPretravel          = v    }
            if let v = try container.decodeIfPresent(UInt.self, forKey: .pretravelSpeed)        {   self.pretravelSpeed         = v    }
            if let v = try container.decodeIfPresent(String.self, forKey: .hotwireSettingComment){  self.hotwireSettingComment  = v    }
            if let v = try container.decodeIfPresent([CuttingPosition].self, forKey: .positions){   self.positions              = v    }
        }
        
    }
    private var data:                           FCalcData               = FCalcData()
    private var mergingData:                    FCalcData?              = nil
     
        
    private var     showAxisGraph:              Bool                    = false
    private var     showShapeGraph:             Bool                    = true
    private var     showCutterGraph:            Bool                    = true
    private var     showBlockGraph:             Bool                    = true
    private var     showShapeCutGraph:          Bool                    = true
    private var     simulationSpeed:            Double                  = 10.0
    private var     previewDiameter:            Double                  = 2.0
        
    // Scene Nodes for Preview
    private var previewNode:                    SCNNode                 = SCNNode()
    private var cameraNode:                     SCNNode                 = SCNNode()
    private var blockNode:                      SCNNode                 = SCNNode()
    private var cutterNode:                     SCNNode                 = SCNNode()
    private var shapeNode:                      SCNNode                 = SCNNode()
    private var shapeCutNode:                   SCNNode                 = SCNNode()
    private var axisNode:                       SCNNode                 = SCNNode()
    private var wireNode:                       SCNNode                 = SCNNode()
    private var simulationTimer:                Timer?                  = nil
    private var mergingShapeNode:               SCNNode                 = SCNNode()
    private var mergingShapeCutNode:            SCNNode                 = SCNNode()
    
    // Colors for Preview
    private var     axisColor:                  NSColor                 = NSColor.orange.withAlphaComponent(0.4)
    private var     axisColorHotwire:           NSColor                 = NSColor.orange
    private var     axisColorAlert:             NSColor                 = NSColor.red
    private var     shapeColor:                 NSColor                 = NSColor.blue.withAlphaComponent(0.4)
    private var     shapeColorHotwire:          NSColor                 = NSColor.blue
    private var     mergingShapeColor:          NSColor                 = NSColor.green.withAlphaComponent(0.4)
    private var     mergingShapeColorHotwire:   NSColor                 = NSColor.green
    private var     blockColor:                 NSColor                 = NSColor.black
    private var     cutterColor:                NSColor                 = NSColor.gray
    private var     wireColor:                  NSColor                 = NSColor.red
    
    // hierin liegen die eigentlichen Daten
    public var numberOfPositions:               Int {
        get {
            return data.positions.count
        }
        set {
            
        }
    }
    public var     markedPosition:              Int?                    = nil {
        didSet {
            updateWireNode()
        }
    }
    
        
    private class CuttingPosition : Codable {
        var x1Shape:                    Double                  = 0.0       // die originalen Shape daten
        var y1Shape:                    Double                  = 0.0
        var w1Shape:                    Double                  = 0.0
        var x2Shape:                    Double                  = 0.0
        var y2Shape:                    Double                  = 0.0
        var w2Shape:                    Double                  = 0.0
        
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
    
        var gcode:                      String                  = ""
        
        public func copy() -> CuttingPosition {
            let new             = CuttingPosition()
            new.x1Shape         = self.x1Shape
            new.y1Shape         = self.y1Shape
            new.w1Shape         = self.w1Shape
            new.x2Shape         = self.x2Shape
            new.y2Shape         = self.y2Shape
            new.w2Shape         = self.w2Shape
            
            new.x1Axis          = self.x1Axis
            new.y1Axis          = self.y1Axis
            new.x2Axis          = self.x2Axis
            new.y2Axis          = self.y2Axis
            
            new.x1Block         = self.x1Block
            new.y1Block         = self.y1Block
            new.w1Block         = self.w1Block
            new.x2Block         = self.x2Block
            new.y2Block         = self.y2Block
            new.w2Block         = self.w2Block
                
            new.hotwire         = self.hotwire
            new.pretravel       = self.pretravel
            new.feedSpeed       = self.feedSpeed
            
            new.gcode           = self.gcode
            return new
        }
        init() {
                
        }
        required init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
              
            if let v = try container.decodeIfPresent(Double.self, forKey: .x1Shape)             {   self.x1Shape            = v    }
            if let v = try container.decodeIfPresent(Double.self, forKey: .y1Shape)             {   self.y1Shape            = v    }
            if let v = try container.decodeIfPresent(Double.self, forKey: .w1Shape)             {   self.w1Shape            = v    }
            if let v = try container.decodeIfPresent(Double.self, forKey: .x2Shape)             {   self.x2Shape            = v    }
            if let v = try container.decodeIfPresent(Double.self, forKey: .y2Shape)             {   self.y2Shape            = v    }
            if let v = try container.decodeIfPresent(Double.self, forKey: .w2Shape)             {   self.w2Shape            = v    }
            if let v = try container.decodeIfPresent(Double.self, forKey: .x1Axis)              {   self.x1Axis             = v    }
            if let v = try container.decodeIfPresent(Double.self, forKey: .y1Axis)              {   self.y1Axis             = v    }
            if let v = try container.decodeIfPresent(Double.self, forKey: .x2Axis)              {   self.x2Axis             = v    }
            if let v = try container.decodeIfPresent(Double.self, forKey: .y2Axis)              {   self.y2Axis             = v    }
            if let v = try container.decodeIfPresent(Double.self, forKey: .x1Block)             {   self.x1Block            = v    }
            if let v = try container.decodeIfPresent(Double.self, forKey: .y1Block)             {   self.y1Block            = v    }
            if let v = try container.decodeIfPresent(Double.self, forKey: .w1Block)             {   self.w1Block            = v    }
            if let v = try container.decodeIfPresent(Double.self, forKey: .x2Block)             {   self.x2Block            = v    }
            if let v = try container.decodeIfPresent(Double.self, forKey: .y2Block)             {   self.y2Block            = v    }
            if let v = try container.decodeIfPresent(Double.self, forKey: .w2Block)             {   self.w2Block            = v    }
            if let v = try container.decodeIfPresent(Bool.self, forKey: .hotwire)               {   self.hotwire            = v    }
            if let v = try container.decodeIfPresent(Bool.self, forKey: .pretravel)             {   self.pretravel          = v    }
            if let v = try container.decodeIfPresent(Double.self, forKey: .feedSpeed)           {   self.feedSpeed          = v    }
            if let v = try container.decodeIfPresent(String.self, forKey: .gcode)               {   self.gcode              = v    }
        }
            
    }
    
    init() {
        loadReg()
        initShape()
        _ = initializeGraph()
        _ = generatePreview()
    }
    // MARK: - Import / Export
    private func initShape() {
        data.positions.removeAll()
        
        // Shapeverschiebung löschen
        data.shapeX                 = 0.0
        data.shapeY                 = 0.0
        data.shapeRotationY         = 0.0
        data.shapeRotationW         = 0.0
        data.shapeChangeAxis        = false
        data.shapeMirrorHorizontal  = false
        data.shapeMirrorVertical    = false
        data.shapeReverse           = false
        data.blockRotation          = 0.0
        
        stop()      // stop the simulation
        
        requestUpdateSettingsTable()
    }
    public func importShapeFromFile(_ file: String?) -> Int {
        guard let file = file else {
            requestUpdateStatusText("Invalid filename or path.")
            return -1;
        }
        
        
        let fileExt     = URL(fileURLWithPath: file).pathExtension
        
        if (fileExt == "FCF") || (fileExt == "fcf") {
            // If you try to import a foamcutter file, handle it as you would import it in addition
            return loadFromFile(file, withMerge: true)
        }
        
        
        
        
        //read text file line by line
        errno = 0
        if freopen(file, "r", stdin) == nil {
            perror(file)
            requestUpdateStatusText("Unable to open file.")
            return -1
        }
        
        mergingData = nil
        if data.positions.count > 0 {
            // data can be merged...
            // save original data
            mergingData = data.copy() as FCalcData
        }
        if self.file == nil {
            self.file              = file      // store filename incl path
            self.projectName       = URL(fileURLWithPath: file).deletingPathExtension().lastPathComponent
        }
        initShape()
        
        
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
                                 w2: data.shapeWidth)
                }
            }
            
        
        } else if (fileExt == "gcode") || (fileExt == "GCODE") || (fileExt == "nc") || (fileExt == "NC") {
            var x:                  Double = 0.0
            var y:                  Double = 0.0
            var u:                  Double = 0.0
            var z:                  Double = 0.0
            var modeRelativ:        Bool   = false
            var newPositionValues:  Bool   = false
            var asInch:             Bool   = false
            
            func getValue(_ v: Double) -> Double {
                if asInch == false {
                    return v
                } else {
                    return (v * 25.4)
                }
            }
            func decodeGcodeCommand(_ line: String?) -> String? {
                guard let line = line else {
                    return nil
                }
                if line.hasPrefix("G17") {
                    return nil
                }
                if line.hasPrefix("G21") {
                    asInch = false
                    return String(line.dropFirst("G21".count))
                }
                if line.hasPrefix("G20") {
                    asInch = true
                    return String(line.dropFirst("G20".count))
                }
                if line.hasPrefix("G01") {
                    return String(line.dropFirst("G01".count))
                }
                if line.hasPrefix("G00") {
                    return String(line.dropFirst("G00".count))
                }
                if line.hasPrefix("G90") {
                    modeRelativ = false
                    return String(line.dropFirst("G90".count))
                }
                if line.hasPrefix("G91") {
                    modeRelativ = true
                    return String(line.dropFirst("G91".count))
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
                if line.hasPrefix(";") {
                    return nil
                }
                if line.hasPrefix("(") {
                    return nil
                }
                if line.hasPrefix("G0") {
                    return String(line.dropFirst("G0".count))
                }
                if line.hasPrefix("G1") {
                    return String(line.dropFirst("G1".count))
                }
                return nil
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
                            x = x + getValue(v)
                        } else {
                            x = getValue(v)
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
                            y = y + getValue(v)
                        } else {
                            y = getValue(v)
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
                            u = u + getValue(v)
                        } else {
                            u = getValue(v)
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
                            z = z + getValue(v)
                        } else {
                            z = getValue(v)
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
                                     w2: data.shapeWidth)
                    }
                    
                }
            }
            
        } else {
            requestUpdateStatusText("Unable to import file. Unkown extension or format.")
            return -1
        }
        // alles neu berechnen
        _ = calculateShape()
        // graph aufbauen
        _ = generatePreview()
        requestUpdateStatusText("File " + URL(fileURLWithPath: file).lastPathComponent  + " imported.")
        return 0
    }
    
    // still under construction
    private func addShapeLine( x1:       Double,
                               y1:       Double,
                               w1:       Double,
                               x2:       Double,
                               y2:       Double,
                               w2:       Double) {
        
        let position:       CuttingPosition         = CuttingPosition()
        position.x1Shape     = x1
        position.y1Shape     = y1
        position.w1Shape     = w1
        position.x2Shape     = x2
        position.y2Shape     = y2
        position.w2Shape     = w2
        
        data.positions.append(position)
    }
    public func exportGCodeToFile(_ file: String?) -> Int {
        guard let file = file else {
            requestUpdateStatusText("Invalid filename or path.")
            return -1;
        }
        guard data.positions.count > 0 else {
            NSLog("Keine Daten vorhanden")
            return -1;
        }
        guard calculateShape() == 0 else {                          // wichtig, damit bei koordinatenänderungen alle berechnungen (z.B. Feedspeed) sauber aufgebaut werden
            requestUpdateStatusText("Unable to calculate shape.")
            return -1
        }
        guard generateGCode() == 0 else {
            requestUpdateStatusText("Unable to generate gcode for line items.")
            return -1
        }
        
        self.file       = file      // store filename incl path
        self.projectName       = URL(fileURLWithPath: file).deletingPathExtension().lastPathComponent
                
         
        // Schreibe in ie Header alle benötigten Einstellung
        var info: String
        
        info = "; FoamCutter G-Code";                                                                       writeLine(info, toFile: file, firstLine: true)
        info = "; .";                                                                                       writeLine(info, toFile: file)
        info = "; "    + labelForKey(.cutter)            + "  " +  valueForKey(.cutter);                    writeLine(info, toFile: file)
        info = "; "    + labelForKey(.cutterWidth)       + "  " +  valueForKey(.cutterWidth);               writeLine(info, toFile: file)
        info = "; "    + labelForKey(.hotwireSettingComment) + "  " +  valueForKey(.hotwireSettingComment); writeLine(info, toFile: file)
        info = "; .";                                                                                       writeLine(info, toFile: file)
        info = "; "    + labelForKey(.block)             + "  " +  valueForKey(.block);                     writeLine(info, toFile: file)
        info = ";    " + labelForKey(.blockMaterialComment) + "  " +  valueForKey(.blockMaterialComment);   writeLine(info, toFile: file)
        info = ";    " + labelForKey(.blockWidth)        + "  " +  valueForKey(.blockWidth);                writeLine(info, toFile: file)
        info = ";    " + labelForKey(.blockHeight)       + "  " +  valueForKey(.blockHeight);               writeLine(info, toFile: file)
        info = ";    " + labelForKey(.blockDepth)        + "  " +  valueForKey(.blockDepth);                writeLine(info, toFile: file)
        info = ";    " + labelForKey(.blockSpacingLeft)  + "  " +  valueForKey(.blockSpacingLeft);          writeLine(info, toFile: file)
        info = ";    " + labelForKey(.blockSpacingFront) + "  " +  valueForKey(.blockSpacingFront);         writeLine(info, toFile: file)
        info = ";    " + labelForKey(.blockSpacingUnder) + "  " +  valueForKey(.blockSpacingUnder);         writeLine(info, toFile: file)
        info = ";    " + labelForKey(.blockRotation)     + "  " +  valueForKey(.blockRotation);             writeLine(info, toFile: file)
        info = "; .";                                                                                       writeLine(info, toFile: file)
        
        
        // XY Plane / mm / Feedrate as unit per minut
        info = "G17\nG21\nG94";                                                                             writeLine(info, toFile: file)
        // Absolute Positionsangaben
        info = "G90F" + valueForKey(.targetFeedSpeed) + "S" + valueForKey(.hotwirePower);                   writeLine(info, toFile: file)
        
        // initiales Hotwire on / off
        if data.positions.first?.hotwire ?? false {
            info = "G4P1\nM3\nG4P" + String(data.hotwirePreheat)
        } else {
            info = "G4P1\nM5"
        }
        writeLine(info, toFile: file)
        
        for position in data.positions {
            writeLine(position.gcode, toFile: file)
        }
        // Hotwire am Ende ausschalten
        info = "G4P1\nM5\n"
        writeLine(info, toFile: file)
         
        
        NSLog("File exportiert: " + (self.projectName ?? ""))
        requestUpdateStatusText("File " + URL(fileURLWithPath: file).lastPathComponent  + " exported.")
        return 0
    }
    private func generateGCode() -> Int {
        guard data.positions.count > 0 else {
            NSLog("Keine Daten vorhanden")
            return -1;
        }
                
        var hotwire         = false
        var pretravelSpeed  = data.pretravelSpeed
        var targetFeedSpeed = data.targetFeedSpeed
        if pretravelSpeed > data.maxFeedSpeed {
            pretravelSpeed = data.maxFeedSpeed
        }
        if targetFeedSpeed > data.maxFeedSpeed {
            targetFeedSpeed = data.maxFeedSpeed
        }
        
        
        for position in data.positions {
            // erzeuge den G-Code
            position.gcode = ""
            if hotwire != position.hotwire {
                hotwire = position.hotwire
                if hotwire {            // hotwire wird eingeschalten
                    position.gcode += "G4P1\nM3\n"
                    position.gcode += "G4P" + String(data.hotwirePreheat) + "\n"      // Preheat für Hotwire
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
            
            position.gcode              += data.labelX1Axis + dtos(position.x1Axis, decimals: data.gcodeDecimals)
                                        +  data.labelY1Axis + dtos(position.y1Axis, decimals: data.gcodeDecimals)
                                        +  data.labelX2Axis + dtos(position.x2Axis, decimals: data.gcodeDecimals)
                                        +  data.labelY2Axis + dtos(position.y2Axis, decimals: data.gcodeDecimals)
        }
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
    // MARK: - Transformation (Move/Flip/...)
    private func moveShape(_ x: Double, _ y: Double) {
        for position in data.positions {
            position.x1Shape    +=  x
            position.x2Shape    +=  x
            position.y1Shape    +=  y
            position.y2Shape    +=  y
        }
    }
    private func changeAxis() {
        var mem: Double
        var minW: Double        = data.positions.first?.w1Shape  ?? 0.0
        var maxW: Double        = data.positions.first?.w1Shape  ?? 0.0
        for position in data.positions {
            if position.w1Shape > maxW        { maxW = position.w1Shape }
            if position.w2Shape > maxW        { maxW = position.w2Shape }
            if position.w1Shape < minW        { minW = position.w1Shape }
            if position.w2Shape < minW        { minW = position.w2Shape }
        }
        
        for position in data.positions {
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
    private func mirrorHorizontal() {
        var mem: Double
        var minX: Double        = data.positions.first?.x1Shape  ?? 0.0
        var minY: Double        = data.positions.first?.y1Shape  ?? 0.0
        var maxX: Double        = data.positions.first?.x1Shape  ?? 0.0
        var maxY: Double        = data.positions.first?.y1Shape  ?? 0.0
        
        // find min and max dimensions
        for position in data.positions {
            if position.x1Shape > maxX        { maxX = position.x1Shape }
            if position.x2Shape > maxX        { maxX = position.x2Shape }
            if position.y1Shape > maxY        { maxY = position.y1Shape }
            if position.y2Shape > maxY        { maxY = position.y2Shape }
            if position.x1Shape < minX        { minX = position.x1Shape }
            if position.x2Shape < minX        { minX = position.x2Shape }
            if position.y1Shape < minY        { minY = position.y1Shape }
            if position.y2Shape < minY        { minY = position.y2Shape }
        }
        
        // mirror and store into new array reverse sorted
        var mirroredPositions: [CuttingPosition] = []
        for position in data.positions {
            //mem                 = maxX - position.x1Shape
            //position.x1Shape    = minX + mem
            //mem                 = maxX - position.x2Shape
            //position.x2Shape    = minX + mem
            mem                 = maxY - position.y1Shape
            position.y1Shape    = minY + mem
            mem                 = maxY - position.y2Shape
            position.y2Shape    = minY + mem
            
            mirroredPositions.insert(position, at: 0)
        }
        
        // remove old positions
        data.positions.removeAll()
        
        // add the flipped positions
        data.positions   += mirroredPositions
        
    }
    private func mirrorVertical() {
        var mem: Double
        var minX: Double        = data.positions.first?.x1Shape  ?? 0.0
        var minY: Double        = data.positions.first?.y1Shape  ?? 0.0
        var maxX: Double        = data.positions.first?.x1Shape  ?? 0.0
        var maxY: Double        = data.positions.first?.y1Shape  ?? 0.0
        
        // find min and max dimensions
        for position in data.positions {
            if position.x1Shape > maxX        { maxX = position.x1Shape }
            if position.x2Shape > maxX        { maxX = position.x2Shape }
            if position.y1Shape > maxY        { maxY = position.y1Shape }
            if position.y2Shape > maxY        { maxY = position.y2Shape }
            if position.x1Shape < minX        { minX = position.x1Shape }
            if position.x2Shape < minX        { minX = position.x2Shape }
            if position.y1Shape < minY        { minY = position.y1Shape }
            if position.y2Shape < minY        { minY = position.y2Shape }
        }
        
        // mirror and store into new array reverse sorted
        var mirroredPositions: [CuttingPosition] = []
        for position in data.positions {
            mem                 = maxX - position.x1Shape
            position.x1Shape    = minX + mem
            mem                 = maxX - position.x2Shape
            position.x2Shape    = minX + mem
            //mem                 = maxY - position.y1Shape
            //position.y1Shape    = minY + mem
            //mem                 = maxY - position.y2Shape
            //position.y2Shape    = minY + mem
            
            mirroredPositions.append(position) // insert(position, at: 0)
        }
        
        // remove old positions
        data.positions.removeAll()
        
        // add the flipped positions
        data.positions   += mirroredPositions
        
    }
    private func reverseShape() {
        var reversePositions: [CuttingPosition] = []
        for position in data.positions {
            reversePositions.insert(position, at: 0)
        }
        // remove old positions
        data.positions.removeAll()
        // add the reversed positions
        data.positions   += reversePositions
    }
    // MARK: - Shape calculation
    private func calculateShape() -> Int {
        defer {
            // Aktualisierungs-Callback aufrufen
            requestUpdatePositionsTable(nil)
        }
        guard data.positions.count > 0 else {
            NSLog("Keine Daten vorhanden")
            
            return -1;
        }
        
        var lastPosition : CuttingPosition? = nil
        for position in data.positions {
            calculatePosition(position, lastPosition: lastPosition)
            lastPosition    = position
        }
        
        return 0;
    }
    private func calculatePosition(_ position: CuttingPosition, source: PositionTableKey = .x1Shape, lastPosition: CuttingPosition? = nil) {
        var left:                       Double      = 0.0
        var right:                      Double      = 0.0
        var delta:                      Double      = 0.0
        var xNew:                       Double      = 0.0
        var yNew:                       Double      = 0.0
        var wNew:                       Double      = 0.0
        var x:                          Double      = 0.0
        var y:                          Double      = 0.0
        var w:                          Double      = 0.0
        
        
        if (source == .x1Shape) || (source == .y1Shape) || (source == .x2Shape) || (source == .y2Shape) || (source == .w1Shape) || (source == .w2Shape) {
      
            // CALCULATE from shape to block (not foam block, this is block is the rotated and moved shape)
            // Left Side
            x = position.x1Shape
            y = position.y1Shape
            w = position.w1Shape
            
            // Rotation around W-Axis
            xNew    = x * cos(-data.shapeRotationW)
                    - y * sin(-data.shapeRotationW)
            yNew    = x * sin(-data.shapeRotationW)
                    + y * cos(-data.shapeRotationW)
            x       = xNew
            y       = yNew
            
            // Rotation arround Y-Axis
            xNew    = x * cos(-data.shapeRotationY)
                    - w * sin(-data.shapeRotationY)
            wNew    = x * sin(-data.shapeRotationY)
                    + w * cos(-data.shapeRotationY)
            x       = xNew
            w       = wNew
            
            // movement
            xNew    = x + data.shapeX
            yNew    = y + data.shapeY
            wNew    = w + data.shapeSpacingLeft
            
            position.x1Block    = xNew
            position.y1Block    = yNew
            position.w1Block    = wNew
            
            // Right Side
            x = position.x2Shape
            y = position.y2Shape
            w = position.w2Shape
            
            // Rotation around W-Axis
            xNew    = x * cos(-data.shapeRotationW)
                    - y * sin(-data.shapeRotationW)
            yNew    = x * sin(-data.shapeRotationW)
                    + y * cos(-data.shapeRotationW)
            x       = xNew
            y       = yNew
            
            // Rotation arround Y-Axis
            xNew    = x * cos(-data.shapeRotationY)
                    - w * sin(-data.shapeRotationY)
            wNew    = x * sin(-data.shapeRotationY)
                    + w * cos(-data.shapeRotationY)
            x       = xNew
            w       = wNew
            
            // movement
            xNew    = x + data.shapeX
            yNew    = y + data.shapeY
            wNew    = w + data.shapeSpacingLeft
            
            position.x2Block    = xNew
            position.y2Block    = yNew
            position.w2Block    = wNew
              
            /*
            position.x1Block = position.x1Shape * cos(-data.shapeRotationY)
                             - position.w1Shape * sin(-data.shapeRotationY)
                             + data.shapeX
            
            position.w1Block = position.x1Shape * sin(-data.shapeRotationY)
                             + position.w1Shape * cos(-data.shapeRotationY)
                             + data.shapeSpacingLeft
            
            position.y1Block = position.y1Shape
                             + data.shapeY
             
            position.x2Block = position.x2Shape * cos(-data.shapeRotationY)
                             - position.w2Shape * sin(-data.shapeRotationY)
                             + data.shapeX
             
            position.w2Block = position.x2Shape * sin(-data.shapeRotationY)
                             + position.w2Shape * cos(-data.shapeRotationY)
                             + data.shapeSpacingLeft
             
            position.y2Block = position.y2Shape
                             + data.shapeY
            */
                
            // CALCULATE from Block to Axis
            
            delta               = (position.x2Block - position.x1Block) / (position.w2Block - position.w1Block)     // berechne die steigung
            right               = data.cutterWidth - position.w2Block
            left                = position.w1Block
            position.x1Axis     = (position.x1Block) - (delta * left)        // berechne die x1Achse
            position.x2Axis     = (position.x2Block) + (delta * right)       // berechne die x2Achse
            delta               = (position.y2Block - position.y1Block) / (position.w2Block - position.w1Block)     // berechne die steigung
            position.y1Axis     = (position.y1Block) - (delta * left)        // berechne die x1Achse
            position.y2Axis     = (position.y2Block) + (delta * right)       // berechne die x2Achse
             
        } else if (source == .x1Axis) || (source == .y1Axis) || (source == .x2Axis) || (source == .y2Axis) {
            
            delta               = (position.y2Axis - position.y1Axis) / data.cutterWidth    // berechne die steigung
            right               = data.cutterWidth - position.w2Block
            left                = position.w1Block
            position.y1Block    = position.y1Axis    + (delta * left)        // berechne die y1Achse
            position.y2Block    = position.y2Axis    - (delta * right)       // berechne die y2Achse
            
            delta               = (position.x2Axis - position.x1Axis) / data.cutterWidth    // berechne die steigung
            right               = data.cutterWidth - position.w2Block
            left                = position.w1Block
            position.x1Block    = position.x1Axis    + (delta * left)        // berechne die x1Achse
            position.x2Block    = position.x2Axis    - (delta * right)       // berechne die x2Achse
            
            
            position.y1Shape    = position.y1Block
                                - data.shapeY
            position.y2Shape    = position.y2Block
                                - data.shapeY
            
            var x:  Double      = 0.0
            var w:  Double      = 0.0
            
            x                   = position.x1Block - data.shapeX
            w                   = position.w1Block - data.shapeSpacingLeft
            position.x1Shape = x * cos(data.shapeRotationY)
                             - w * sin(data.shapeRotationY)
            position.w1Shape = x * sin(data.shapeRotationY)
                             + w * cos(data.shapeRotationY)
             
            x                   = position.x2Block - data.shapeX
            w                   = position.w2Block - data.shapeSpacingLeft
            position.x2Shape = x * cos(data.shapeRotationY)
                             - w * sin(data.shapeRotationY)
            position.w2Shape = x * sin(data.shapeRotationY)
                             + w * cos(data.shapeRotationY)
            
        }
        
        // berechne die bearbeitungsgeschwindigkeit
        var calcFeedSpeed:      Double = Double(data.targetFeedSpeed)
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
                calcFeedSpeed   = Double(data.maxFeedSpeed)
            } else if dSpeed.isNaN {
                calcFeedSpeed   = Double(data.targetFeedSpeed)
            }  else if dSpeed <= 0.0 {
                calcFeedSpeed   = Double(data.targetFeedSpeed)
            } else {
                calcFeedSpeed  = dSpeed * Double(data.targetFeedSpeed)
            }
        }
        
        position.feedSpeed      = calcFeedSpeed
        if data.fastPretravel == true,
            position.pretravel == true {
            position.feedSpeed      = Double(data.pretravelSpeed)
        } else {
            if let speed = position.feedSpeed {
                if speed > Double(data.maxFeedSpeed) {
                    position.feedSpeed      = Double(data.maxFeedSpeed)
                }
            } else {
                position.feedSpeed      = Double(data.targetFeedSpeed)
            }
            if data.feedSpeedCorrection == false {
                position.feedSpeed      = Double(data.targetFeedSpeed)
            }
        }
        if (position.feedSpeed ?? 0)  < Double(data.targetFeedSpeed) {
            position.feedSpeed = Double(data.targetFeedSpeed)
        }
        
    }
    public enum MergeType: Int {
        case before
        case after
    }
    
    public func merge(_ mergeType: MergeType = .before) -> Int {
        guard let mergingData = self.mergingData,
                  mergingData.positions.count > 0,
                  data.positions.count > 0 else {
            return -1
        }
        
        // copy all Block Positions to Shape Positions, this deletes rotation and movement and handles this as new fix / original position
        for position in mergingData.positions {
            position.x1Shape        = position.x1Block
            position.x2Shape        = position.x2Block
            position.y1Shape        = position.y1Block
            position.y2Shape        = position.y2Block
            position.w1Shape        = position.w1Block - mergingData.shapeSpacingLeft
            position.w2Shape        = position.w2Block - mergingData.shapeSpacingLeft
        }
        for position in data.positions {
            position.x1Shape        = position.x1Block
            position.x2Shape        = position.x2Block
            position.y1Shape        = position.y1Block
            position.y2Shape        = position.y2Block
            position.w1Shape        = position.w1Block - mergingData.shapeSpacingLeft
            position.w2Shape        = position.w2Block - mergingData.shapeSpacingLeft
        }
        var positions:              [CuttingPosition]
        if mergeType == .before {
            positions               =  data.positions
            positions               += mergingData.positions
        } else {
            positions               =  mergingData.positions
            positions               += data.positions
        }
        initShape()
        data.shapeSpacingLeft       = mergingData.shapeSpacingLeft
        data.positions              = positions
        self.mergingData            = nil
        // neu berechnen und Graph aktualisieren
        _ = calculateShape()
        _ = generatePreview()
        
        
        return 0
    }
    public func discard() -> Int {
        guard let mergingData = self.mergingData,
                mergingData.positions.count > 0 else {
            return -1
        }
        self.data           = mergingData.copy() as FCalcData
        self.mergingData    = nil
        // neu berechnen und Graph aktualisieren
        _ = calculateShape()
        _ = generatePreview()
        requestUpdateSettingsTable()
        return 0
    }
    
    
    // MARK: - Preview
    
    private func initializeGraph() -> Int {
        cameraNode                  = SCNNode()
        cameraNode.camera           = SCNCamera()
        cameraNode.camera!.zFar     = (max(data.cutterWidth, data.cutterHeight) + data.cutterDepth) * 3;
        cameraNode.camera!.zNear    = 5.0;
        previewNode.addChildNode(cameraNode)
        
        setCamera(.home)
        
        previewNode.light           = SCNLight()
        previewNode.light!.type = .ambient
        previewNode.light!.color = NSColor(white: 0.67, alpha: 1.0)
        
        return 0
    }
    public func setCamera(_ direction: cameraDirection = .front) {
        switch (direction) {
        case .top:
            cameraNode.position = SCNVector3(x: CGFloat(data.cutterWidth * 0.5),
                                             y: CGFloat(cameraNode.camera!.zFar * 0.5 + data.cutterHeight),
                                             z: 0)
            cameraNode.eulerAngles      = SCNVector3(x: .pi * -0.5,
                                                     y: .pi * 0.0,
                                                     z: .pi * 0.0)
            break
        case .left:
            cameraNode.position = SCNVector3(x: CGFloat(cameraNode.camera!.zFar * -0.5),
                                             y: 0,
                                             z: CGFloat(data.cutterDepth * -0.5))
            cameraNode.eulerAngles      = SCNVector3(x: .pi * 0.0,
                                                     y: .pi * -0.5,
                                                     z: .pi * 0.0)
            break
        case .right:
            cameraNode.position = SCNVector3(x: CGFloat(cameraNode.camera!.zFar * 0.5 + data.cutterWidth),
                                             y: 0,
                                             z: CGFloat(data.cutterDepth * -0.5))
            cameraNode.eulerAngles      = SCNVector3(x: .pi * 0.0,
                                                     y: .pi * 0.5,
                                                     z: .pi * 0.0)
            break
        case .home:
            cameraNode.position = SCNVector3(x: CGFloat(cameraNode.camera!.zFar * -0.3  + data.cutterWidth),
                                             y: CGFloat(cameraNode.camera!.zFar * 0.3   + data.cutterHeight),
                                             z: CGFloat(cameraNode.camera!.zFar * 0.3   - data.cutterDepth))
            cameraNode.eulerAngles      = SCNVector3(x: .pi * -0.25,
                                                     y: .pi * -0.25,
                                                     z: .pi * 0.0)
            break
        default: // front
            cameraNode.position = SCNVector3(x: CGFloat(data.cutterWidth * 0.5),
                                             y: 0,
                                             z: CGFloat(cameraNode.camera!.zFar * 0.5))
            cameraNode.eulerAngles      = SCNVector3(x: .pi * 0.0,
                                                     y: .pi * 0.0,
                                                     z: .pi * 0.0)
            break
            
        }
        
      //  previewNode.addChildNode(cameraNode)
    }
    
    
    private func generatePreview() -> Int {
        defer {
            if let f = callback?.updatePreview(_:) {
                f(previewNode)
            }
        }
        
        
        mergingShapeNode.removeFromParentNode()
        mergingShapeCutNode.removeFromParentNode()
        
        stop()      // stop the simulation
        
        generateFoamBlockNode()
        
        generateMergingShapeNode()
        generateMergingShapeCutNode()
        
        generateShapeNode()
        generateShapeCutNode()
        
        generateCutterNode()
        generateAxisNode()
        
        return 0
    }
    private func sin(_ degrees: Double) -> Double {
        return __sinpi(degrees/180.0)
    }
    private func cos(_ degrees: Double) -> Double {
        return __cospi(degrees/180.0)
    }
    private func generateCutterNode() {
         cutterNode.removeFromParentNode()
        
         var plane:      SCNPlane
         var planeNode:  SCNNode
         
         let node        = SCNNode()
         let color       = cutterColor.withAlphaComponent(0.5)
         
         plane           = SCNPlane(width: CGFloat(data.cutterDepth),
                                    height: CGFloat(data.cutterHeight))
         plane.firstMaterial?.diffuse.contents   = color
         plane.firstMaterial?.isDoubleSided      = true
         planeNode                               = SCNNode(geometry:plane)
         planeNode.eulerAngles.y                 = .pi / 2
         planeNode.position.x                    = CGFloat(data.cutterWidth)        * (-0.5)
         node.addChildNode(planeNode)
         
         planeNode                               = planeNode.clone()
         planeNode.position.x                    = CGFloat(data.cutterWidth)        * (0.5)
         node.addChildNode(planeNode)
         
         node.pivot                              = SCNMatrix4MakeTranslation(CGFloat(-data.cutterWidth)/2.0, CGFloat(-data.cutterHeight)/2.0, CGFloat(data.cutterDepth)/2.0);
         
         cutterNode           = node
         cutterNode.isHidden  = !self.showCutterGraph
         previewNode.addChildNode(cutterNode)
    }
     
    private func generateShapeNode(index: Int? = nil) {
        if let index = index {
            // lösche diese nodes vom index
            // lösche diese nodes vom index und index + 1
            let nodes = shapeNode.childNodes.filter { $0.name == String(index)  }
            for node in nodes {
                node.removeFromParentNode()
            }
            // und berechne diese neu
            if index < self.data.positions.count {
                let position = self.data.positions[index]
                var c = self.shapeColor
                if position.hotwire {
                    c = self.shapeColorHotwire
                }
                shapeNode.addChildNode(drawLine(x1:          position.x1Block,
                                                y1:          position.y1Block,
                                                w1:          position.w1Block,
                                                x2:          position.x2Block,
                                                y2:          position.y2Block,
                                                w2:          position.w2Block,
                                                color:       c,
                                                diameter:    previewDiameter,
                                                index:       index))
            }
        } else {
            // gesamten Shape aktualisieren
            shapeNode.removeFromParentNode()
            shapeNode = SCNNode()
            
            for (i, position) in self.data.positions.enumerated() {
                var c = self.shapeColor
                if position.hotwire {
                    c = self.shapeColorHotwire
                }
                shapeNode.addChildNode(drawLine(x1:          position.x1Block,
                                                y1:          position.y1Block,
                                                w1:          position.w1Block,
                                                x2:          position.x2Block,
                                                y2:          position.y2Block,
                                                w2:          position.w2Block,
                                                color:       c,
                                                diameter:    previewDiameter,
                                                index:       i))
            }
            shapeNode.isHidden   = !self.showShapeGraph
            previewNode.addChildNode(shapeNode)
        }
    }
    private func generateShapeCutNode(index: Int? = nil) {
        if let index = index {
            // lösche diese nodes vom index und index + 1
            let nodes = shapeCutNode.childNodes.filter { ($0.name == String(index)) || ($0.name == String(index + 1)) }
            for node in nodes {
                node.removeFromParentNode()
            }
            
            // und berechne diese neu
            var p1: CuttingPosition?    = nil
            var p2: CuttingPosition!
            var p3: CuttingPosition?    = nil
            
            p2      = self.data.positions[index]
            if index > 0 {
                p1  = self.data.positions[index - 1]
            }
            if index + 1 < self.data.positions.count {
                p3  = self.data.positions[index + 1]
            }
            if let p1 = p1 {
                var c = self.shapeColor
                if p2.hotwire {
                    c = self.shapeColorHotwire
                }
                shapeCutNode.addChildNode(drawLine(x1:             p1.x1Block,
                                                   y1:             p1.y1Block,
                                                   w1:             p1.w1Block,
                                                   x2:             p2.x1Block,
                                                   y2:             p2.y1Block,
                                                   w2:             p2.w1Block,
                                                   color:          c,
                                                   diameter:       previewDiameter,
                                                   index:          index))
                shapeCutNode.addChildNode(drawLine(x1:             p1.x2Block,
                                                   y1:             p1.y2Block,
                                                   w1:             p1.w2Block,
                                                   x2:             p2.x2Block,
                                                   y2:             p2.y2Block,
                                                   w2:             p2.w2Block,
                                                   color:          c,
                                                   diameter:       previewDiameter,
                                                   index:          index))
            }
            if let p3 = p3 {
                var c = self.shapeColor
                if p2.hotwire {
                    c = self.shapeColorHotwire
                }
                shapeCutNode.addChildNode(drawLine(x1:             p2.x1Block,
                                                   y1:             p2.y1Block,
                                                   w1:             p2.w1Block,
                                                   x2:             p3.x1Block,
                                                   y2:             p3.y1Block,
                                                   w2:             p3.w1Block,
                                                   color:          c,
                                                   diameter:       previewDiameter,
                                                   index:          index + 1))
                shapeCutNode.addChildNode(drawLine(x1:             p2.x2Block,
                                                   y1:             p2.y2Block,
                                                   w1:             p2.w2Block,
                                                   x2:             p3.x2Block,
                                                   y2:             p3.y2Block,
                                                   w2:             p3.w2Block,
                                                   color:          c,
                                                   diameter:       previewDiameter,
                                                   index:          index + 1))
            }
        } else {
            // gesamten Shape aktualisieren
            shapeCutNode.removeFromParentNode()
            shapeCutNode = SCNNode()
            
            var x:          Double = 0.0
            var y:          Double = 0.0
            var w:          Double = 0.0
            
            for (i, position) in self.data.positions.enumerated() {
                if i == 0 {
                    x = position.x1Block
                    y = position.y1Block
                    w = position.w1Block
                } else {
                    var c = self.shapeColor
                    if position.hotwire {
                        c = self.shapeColorHotwire
                    }
                    shapeCutNode.addChildNode(drawLine(x1:             x,
                                                       y1:             y,
                                                       w1:             w,
                                                       x2:             position.x1Block,
                                                       y2:             position.y1Block,
                                                       w2:             position.w1Block,
                                                       color:          c,
                                                       diameter:       previewDiameter,
                                                       index:          i))
                    x = position.x1Block
                    y = position.y1Block
                    w = position.w1Block
                }
            }
            
            for (i, position) in data.positions.enumerated() {
                if i == 0 {
                    x = position.x2Block
                    y = position.y2Block
                    w = position.w2Block
                } else {
                    var c = self.shapeColor
                    if position.hotwire {
                        c = self.shapeColorHotwire
                    }
                    shapeCutNode.addChildNode(drawLine(x1:             x,
                                                       y1:             y,
                                                       w1:             w,
                                                       x2:             position.x2Block,
                                                       y2:             position.y2Block,
                                                       w2:             position.w2Block,
                                                       color:          c,
                                                       diameter:       previewDiameter,
                                                       index:          i))
                    x = position.x2Block
                    y = position.y2Block
                    w = position.w2Block
                }
            }
            shapeCutNode.isHidden   = !self.showShapeCutGraph
            previewNode.addChildNode(shapeCutNode)
        }
    }
    private func generateMergingShapeNode(index: Int? = nil) {
        // gesamten Shape aktualisieren
        mergingShapeNode.removeFromParentNode()
        
        guard let positions = self.mergingData?.positions else {
            return
        }
        
        
        mergingShapeNode = SCNNode()
        
        for (i, position) in positions.enumerated() {
            var c = self.mergingShapeColor
            if position.hotwire {
                c = self.mergingShapeColorHotwire
            }
            mergingShapeNode.addChildNode(drawLine(x1:          position.x1Block,
                                                   y1:          position.y1Block,
                                                   w1:          position.w1Block,
                                                   x2:          position.x2Block,
                                                   y2:          position.y2Block,
                                                   w2:          position.w2Block,
                                                   color:       c,
                                                   diameter:    previewDiameter,
                                                   index:       i))
        }
        mergingShapeNode.isHidden   = !self.showShapeGraph
        previewNode.addChildNode(mergingShapeNode)
    }
    private func generateMergingShapeCutNode(index: Int? = nil) {
        // gesamten Shape aktualisieren
        mergingShapeCutNode.removeFromParentNode()
        
        guard let positions = self.mergingData?.positions else {
            return
        }
        
        mergingShapeCutNode = SCNNode()
        
        var x:          Double = 0.0
        var y:          Double = 0.0
        var w:          Double = 0.0
        
        for (i, position) in positions.enumerated() {
            if i == 0 {
                x = position.x1Block
                y = position.y1Block
                w = position.w1Block
            } else {
                var c = self.mergingShapeColor
                if position.hotwire {
                    c = self.mergingShapeColorHotwire
                }
                mergingShapeCutNode.addChildNode(drawLine(x1:             x,
                                                          y1:             y,
                                                          w1:             w,
                                                          x2:             position.x1Block,
                                                          y2:             position.y1Block,
                                                          w2:             position.w1Block,
                                                          color:          c,
                                                          diameter:       previewDiameter,
                                                          index:          i))
                x = position.x1Block
                y = position.y1Block
                w = position.w1Block
            }
        }
        
        for (i, position) in positions.enumerated() {
            if i == 0 {
                x = position.x2Block
                y = position.y2Block
                w = position.w2Block
            } else {
                var c = self.mergingShapeColor
                if position.hotwire {
                    c = self.mergingShapeColorHotwire
                }
                mergingShapeCutNode.addChildNode(drawLine(x1:             x,
                                                          y1:             y,
                                                          w1:             w,
                                                          x2:             position.x2Block,
                                                          y2:             position.y2Block,
                                                          w2:             position.w2Block,
                                                          color:          c,
                                                          diameter:       previewDiameter,
                                                          index:          i))
                x = position.x2Block
                y = position.y2Block
                w = position.w2Block
            }
        }
        mergingShapeCutNode.isHidden   = !self.showShapeCutGraph
        previewNode.addChildNode(mergingShapeCutNode)
    }
     
     private func updateWireNode()  {
         wireNode.removeFromParentNode()
         wireNode    = SCNNode()
         
         guard let markedPosition = markedPosition else {
             return
         }
         if markedPosition >= data.positions.count {
             self.markedPosition = nil
             return
         }
         let position = data.positions[markedPosition]
         
         
         //SCNTransaction.begin()
        // SCNTransaction.animationDuration = 0.5
         wireNode.addChildNode(drawLine(x1:             position.x1Axis,
                                        y1:             position.y1Axis,
                                        w1:             0.0,
                                        x2:             position.x2Axis,
                                        y2:             position.y2Axis,
                                        w2:             data.cutterWidth,
                                        color:          wireColor,
                                        diameter:       self.previewDiameter))
         previewNode.addChildNode(wireNode)
         
         
       //  SCNTransaction.commit()
         var msg = "Index: "
         msg += String(markedPosition)
         msg += " - Block X/Y/W:"
         msg += valueFor(.x1Block, index: markedPosition) ?? ""
         msg += "/"
         msg += valueFor(.y1Block, index: markedPosition) ?? ""
         msg += "/"
         msg += valueFor(.w1Block, index: markedPosition) ?? ""
         msg += " - U/Z/W:"
         msg += valueFor(.x2Block, index: markedPosition) ?? ""
         msg += "/"
         msg += valueFor(.y2Block, index: markedPosition) ?? ""
         msg += "/"
         msg += valueFor(.w2Block, index: markedPosition) ?? ""
         NSLog(msg)
        
         requestUpdateStatusText(msg)
        
     }
     private func generateAxisNode(index: Int? = nil)  {
        if let index = index {
            // lösche diese nodes vom index und index + 1
            let nodes = axisNode.childNodes.filter { ($0.name == String(index)) || ($0.name == String(index + 1)) }
            for node in nodes {
                node.removeFromParentNode()
            }
           
           // und berechne diese neu
           var p1: CuttingPosition?    = nil
           var p2: CuttingPosition!
           var p3: CuttingPosition?    = nil
           
           p2      = self.data.positions[index]
           if index > 0 {
               p1  = self.data.positions[index - 1]
           }
           if index + 1 < self.data.positions.count {
               p3  = self.data.positions[index + 1]
           }
           if let p1 = p1 {
               var color = axisColor
               if p2.hotwire {
                   color = axisColorHotwire
               }
               if (p2.x1Axis < 0) || (p2.y1Axis < 0) || (p2.x1Axis > data.cutterDepth) || (p2.y1Axis > data.cutterHeight) ||
                  (p1.x1Axis < 0) || (p1.y1Axis < 0) || (p1.x1Axis > data.cutterDepth) || (p1.y1Axis > data.cutterHeight) {
                   color = axisColorAlert
               }
               axisNode.addChildNode(drawLine(x1:             p1.x1Axis,
                                              y1:             p1.y1Axis,
                                              w1:             0.0,
                                              x2:             p2.x1Axis,
                                              y2:             p2.y1Axis,
                                              w2:             0.0,
                                              color:          color,
                                              diameter:       previewDiameter,
                                              index:          index))
               color = axisColor
               if p2.hotwire {
                   color = axisColorHotwire
               }
               if (p2.x2Axis < 0) || (p2.y2Axis < 0) || (p2.x2Axis > data.cutterDepth) || (p2.y2Axis > data.cutterHeight) ||
                  (p1.x2Axis < 0) || (p1.y2Axis < 0) || (p1.x2Axis > data.cutterDepth) || (p1.y2Axis > data.cutterHeight) {
                   color = axisColorAlert
               }
               axisNode.addChildNode(drawLine(x1:             p1.x2Axis,
                                              y1:             p1.y2Axis,
                                              w1:             data.cutterWidth,
                                              x2:             p2.x2Axis,
                                              y2:             p2.y2Axis,
                                              w2:             data.cutterWidth,
                                              color:          color,
                                              diameter:       previewDiameter,
                                              index:          index))
            
            }
            if let p3 = p3 {
                var color = axisColor
                if p3.hotwire {
                    color = axisColorHotwire
                }
                if (p2.x1Axis < 0) || (p2.y1Axis < 0) || (p2.x1Axis > data.cutterDepth) || (p2.y1Axis > data.cutterHeight) ||
                   (p3.x1Axis < 0) || (p3.y1Axis < 0) || (p3.x1Axis > data.cutterDepth) || (p3.y1Axis > data.cutterHeight) {
                    color = axisColorAlert
                }
                axisNode.addChildNode(drawLine(x1:             p2.x1Axis,
                                               y1:             p2.y1Axis,
                                               w1:             0.0,
                                               x2:             p3.x1Axis,
                                               y2:             p3.y1Axis,
                                               w2:             0.0,
                                               color:          color,
                                               diameter:       previewDiameter,
                                               index:          index + 1))
                
               
                if (p2.x2Axis < 0) || (p2.y2Axis < 0) || (p2.x2Axis > data.cutterDepth) || (p2.y2Axis > data.cutterHeight) ||
                   (p3.x2Axis < 0) || (p3.y2Axis < 0) || (p3.x2Axis > data.cutterDepth) || (p3.y2Axis > data.cutterHeight) {
                    color = axisColorAlert
                }
                axisNode.addChildNode(drawLine(x1:             p2.x2Axis,
                                               y1:             p2.y2Axis,
                                               w1:             data.cutterWidth,
                                               x2:             p3.x2Axis,
                                               y2:             p3.y2Axis,
                                               w2:             data.cutterWidth,
                                               color:          color,
                                               diameter:       previewDiameter,
                                               index:          index + 1))
           }
            
            
        } else {
             axisNode.removeFromParentNode()
             axisNode = SCNNode()
            
             var x:          Double = 0.0
             var y:          Double = 0.0
             
             for (i, position) in data.positions.enumerated() {
                 if i == 0 {
                     x = position.x1Axis
                     y = position.y1Axis
                 } else {
                     var color = axisColor
                     if position.hotwire {
                         color = axisColorHotwire
                     }
                     if (position.x1Axis < 0) || (position.y1Axis < 0) || (position.x1Axis > data.cutterDepth) || (position.y1Axis > data.cutterHeight) ||
                        (x < 0) || (y < 0) || (x > data.cutterDepth) || (y > data.cutterHeight) {
                         color = axisColorAlert
                     }

                     axisNode.addChildNode(drawLine(x1:             x,
                                                    y1:             y,
                                                    w1:             0.0,
                                                    x2:             position.x1Axis,
                                                    y2:             position.y1Axis,
                                                    w2:             0.0,
                                                    color:          color,
                                                    diameter:       self.previewDiameter,
                                                    index:          i))
                     x = position.x1Axis
                     y = position.y1Axis
                 }
             }
             
             for (i, position) in data.positions.enumerated() {
                 if i == 0 {
                     x = position.x2Axis
                     y = position.y2Axis
                 } else {
                     var color = axisColor
                     if position.hotwire {
                         color = axisColorHotwire
                     }
                     if (position.x2Axis < 0) || (position.y2Axis < 0) || (position.x2Axis > data.cutterDepth) || (position.y2Axis > data.cutterHeight) ||
                        (x < 0) || (y < 0) || (x > data.cutterDepth) || (y > data.cutterHeight) {
                         color = axisColorAlert
                     }

                     axisNode.addChildNode(drawLine(x1:             x,
                                                y1:             y,
                                                w1:             data.cutterWidth,
                                                x2:             position.x2Axis,
                                                y2:             position.y2Axis,
                                                w2:             data.cutterWidth,
                                                color:          color,
                                                diameter:       self.previewDiameter,
                                                index:          i))
                     x = position.x2Axis
                     y = position.y2Axis
                 }
             }
             
             axisNode.isHidden    = !self.showAxisGraph
             previewNode.addChildNode(axisNode)
            
        }
     }

     private func drawLine(x1:       Double,
                           y1:       Double,
                           w1:       Double,
                           x2:       Double,
                           y2:       Double,
                           w2:       Double,
                           color:    NSColor,
                           diameter: Double    = 2.0,
                           index:    Int? = nil) -> SCNNode {

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
         lineNode.name = String(index ?? 0)
         return lineNode
     }
     
    
     private func generateFoamBlockNode() {
         
         var h:          CGFloat
         var edge:       SCNCapsule
         var edgeNode:   SCNNode
         let node        = SCNNode()
         let color       = blockColor.withAlphaComponent(0.5)
         
         
         // draw the box
         let box         = SCNBox(width: CGFloat(data.blockWidth),
                                  height: CGFloat(data.blockHeight),
                                  length: CGFloat(data.blockDepth),
                                  chamferRadius: CGFloat(previewDiameter/2))
         box.firstMaterial?.diffuse.contents = color
         node.addChildNode(SCNNode(geometry: box))
         
         // long edges
         h                                       = CGFloat(data.blockWidth)
         edge                                    = SCNCapsule(capRadius: CGFloat(previewDiameter/2), height: h)
         edge.radialSegmentCount                 = 12
         edge.firstMaterial?.diffuse.contents    = blockColor
         edgeNode                                = SCNNode(geometry: edge)
         edgeNode.position.y                     = CGFloat(data.blockHeight - previewDiameter)        * (-0.5)
         edgeNode.position.z                     = CGFloat(data.blockDepth - previewDiameter)         * (-0.5)
         edgeNode.eulerAngles.x                  = .pi / 2
         edgeNode.eulerAngles.y                  = .pi / 2
         node.addChildNode(edgeNode)
         
         edgeNode                                = edgeNode.clone()
         edgeNode.position.y                     = CGFloat(data.blockHeight - previewDiameter)        * (-0.5)
         edgeNode.position.z                     = CGFloat(data.blockDepth - previewDiameter)         * (0.5)
         node.addChildNode(edgeNode)
         
         edgeNode                                = edgeNode.clone()
         edgeNode.position.y                     = CGFloat(data.blockHeight - previewDiameter)        * (0.5)
         edgeNode.position.z                     = CGFloat(data.blockDepth - previewDiameter)         * (-0.5)
         node.addChildNode(edgeNode)
         
         edgeNode                                = edgeNode.clone()
         edgeNode.position.y                     = CGFloat(data.blockHeight - previewDiameter)        * (0.5)
         edgeNode.position.z                     = CGFloat(data.blockDepth - previewDiameter)         * (0.5)
         node.addChildNode(edgeNode)
         
         // short edges
         h                                       = CGFloat(data.blockHeight)
         edge                                    = SCNCapsule(capRadius: CGFloat(previewDiameter/2), height: h)
         edge.radialSegmentCount                 = 12
         edge.firstMaterial?.diffuse.contents    = blockColor
         edgeNode                                = SCNNode(geometry: edge)
         edgeNode.eulerAngles.y                  = .pi / 2
         edgeNode.position.z                     = CGFloat(data.blockDepth - previewDiameter)         * (-0.5)
         edgeNode.position.x                     = CGFloat(data.blockWidth - previewDiameter)         * (-0.5)
         node.addChildNode(edgeNode)
         
         edgeNode                                = edgeNode.clone()
         edgeNode.position.z                     = CGFloat(data.blockDepth - previewDiameter)         * (0.5)
         edgeNode.position.x                     = CGFloat(data.blockWidth - previewDiameter)         * (-0.5)
         node.addChildNode(edgeNode)
         
         edgeNode                                = edgeNode.clone()
         edgeNode.position.z                     = CGFloat(data.blockDepth - previewDiameter)         * (-0.5)
         edgeNode.position.x                     = CGFloat(data.blockWidth - previewDiameter)         * (0.5)
         node.addChildNode(edgeNode)
         
         edgeNode                                = edgeNode.clone()
         edgeNode.position.z                     = CGFloat(data.blockDepth - previewDiameter)         * (0.5)
         edgeNode.position.x                     = CGFloat(data.blockWidth - previewDiameter)         * (0.5)
         node.addChildNode(edgeNode)
         
         h                                       = CGFloat(data.blockDepth)
         edge                                    = SCNCapsule(capRadius: CGFloat(previewDiameter/2), height: h)
         edge.radialSegmentCount                 = 12
         edge.firstMaterial?.diffuse.contents    = blockColor
         edgeNode                                = SCNNode(geometry: edge)
         edgeNode.eulerAngles.x                  = .pi / 2
         edgeNode.position.x                     = CGFloat(data.blockWidth - previewDiameter)         * (-0.5)
         edgeNode.position.y                     = CGFloat(data.blockHeight - previewDiameter)        * (-0.5)
         node.addChildNode(edgeNode)
         
         edgeNode                                = edgeNode.clone()
         edgeNode.position.x                     = CGFloat(data.blockWidth - previewDiameter)         * (0.5)
         edgeNode.position.y                     = CGFloat(data.blockHeight - previewDiameter)        * (-0.5)
         node.addChildNode(edgeNode)
         
         edgeNode                                = edgeNode.clone()
         edgeNode.position.x                     = CGFloat(data.blockWidth - previewDiameter)         * (-0.5)
         edgeNode.position.y                     = CGFloat(data.blockHeight - previewDiameter)        * (0.5)
         node.addChildNode(edgeNode)
         
         edgeNode                                = edgeNode.clone()
         edgeNode.position.x                     = CGFloat(data.blockWidth - previewDiameter)         * (0.5)
         edgeNode.position.y                     = CGFloat(data.blockHeight - previewDiameter)        * (0.5)
         node.addChildNode(edgeNode)
         
         node.pivot                              = SCNMatrix4MakeTranslation(CGFloat(-data.blockWidth)/2.0, CGFloat(-data.blockHeight)/2.0, CGFloat(data.blockDepth)/2.0);
         node.eulerAngles.y                      = CGFloat(data.blockRotation / 180.0 * .pi)
         node.eulerAngles.z                      = CGFloat(/* rotationX */ 0.0 / 180.0 * .pi)
         node.eulerAngles.x                      = CGFloat(/*-rotationW */ 0.0 / 180.0 * .pi)
         
         node.position.y                         = CGFloat(data.blockSpacingUnder)
         node.position.z                         = CGFloat(-data.blockSpacingFront)
         node.position.x                         = CGFloat(data.blockSpacingLeft)
        
         
         blockNode.removeFromParentNode()
         blockNode                = node
         blockNode.isHidden       = !self.showBlockGraph
         previewNode.addChildNode(blockNode)

     }
    // MARK: - Supportfunctions
    
     
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
    public func requestUpdateStatusText(_ statusText: String?) {
        if let f = callback?.updateStatusText(_:) {
            f(statusText)
        }
    }

// MARK: - Load / Save / New
    public func newFile() -> Int {
        // new file is clearing all setting.
        initShape()
        self.file               = nil
        self.projectName        = nil
        mergingData             = nil
        _ = calculateShape()
        _ = generatePreview()
        requestUpdateStatusText("New File.")
        return 0
    }
    public func saveToFile(_ file: String?) -> Int {
        guard data.positions.count > 0 else {
            NSLog("No data available")
            requestUpdateStatusText("Unable to save file: No data available.")
            return -1;
        }
        guard let file = file else {
            NSLog("No filename")
            return -1;
        }
        let url        = URL(fileURLWithPath: file)
        let encoder = JSONEncoder()
        guard let encodedData = try? encoder.encode(self.data) else {
            NSLog("Unable do encode")
            requestUpdateStatusText("Unable to save file: Encoding Error.")
            return -1
        }
        try? encodedData.write(to: url)
        
        self.file           = file      // store filename incl path
        self.projectName    = URL(fileURLWithPath: file).deletingPathExtension().lastPathComponent
        requestUpdateStatusText("File saved as " + URL(fileURLWithPath: file).lastPathComponent)
        return 0
    }
    public func loadFromFile(_ file: String?) -> Int {
        return loadFromFile(file, withMerge: false)
    }
    private func loadFromFile(_ file: String?, withMerge: Bool = false) -> Int {
        guard let file = file else {
            NSLog("No filename")
            requestUpdateStatusText("Unable to open file: Invalide filename or path.")
            return -1;
        }
        // alte Daten sichern für merge
        mergingData     = nil
        if withMerge == true,
           data.positions.count > 0 {
            // data can be merged...
            // save original data
            mergingData = data.copy() as FCalcData
        } else {
            self.file              = file      // store filename incl path
            self.projectName       = URL(fileURLWithPath: file).deletingPathExtension().lastPathComponent
        }
        // File Laden
        let url         = URL(fileURLWithPath: file)
        let jsonData    = try? Data(contentsOf: url)
        let decoder     = JSONDecoder()
        self.data       = try! decoder.decode(FCalcData.self, from: jsonData!)
        
        
        
        _ = calculateShape()
        _ = generatePreview()
        requestUpdateSettingsTable()
        requestUpdateStatusText("File " + URL(fileURLWithPath: file).lastPathComponent  + " opened.")
        return 0
    }


// MARK: - Simulation

    @objc public func play() {
        guard data.positions.count > 0 else {
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
            (index + 1) < (data.positions.count) {
            let position        = data.positions[index]
            let nextPosition    = data.positions[index + 1]
            var d1Axis: Double
            var d2Axis: Double
            
            d1Axis      = (position.x1Axis - nextPosition.x1Axis) * (position.x1Axis - nextPosition.x1Axis)
            d1Axis     += (position.y1Axis - nextPosition.y1Axis) * (position.y1Axis - nextPosition.y1Axis)
            d1Axis      = sqrt(d1Axis)
            
            d2Axis      = (position.x2Axis - nextPosition.x2Axis) * (position.x2Axis - nextPosition.x2Axis)
            d2Axis     += (position.y2Axis - nextPosition.y2Axis) * (position.y2Axis - nextPosition.y2Axis)
            d2Axis      = sqrt(d2Axis)
            
            d1Axis      = max(d1Axis, d2Axis)
            
            time        = d1Axis / (position.feedSpeed ?? Double(data.targetFeedSpeed))
            time       *= 60    // mm/min >> seconds
            time       /= simulationSpeed     // time elapse (fast)
        }
               
        simulationTimer =   Timer.scheduledTimer(timeInterval:  time,
                                                 target:        self,
                                                 selector:      #selector(play),
                                                 userInfo:      nil,
                                                 repeats:       false)
    }
    
    public func pause() {
        simulationTimer?.invalidate()
        simulationTimer     = nil
    }
    public func playPause() {
        if simulationTimer == nil {
            play()
        } else {
            pause()
        }
    }
    
    public func stop() {
        simulationTimer?.invalidate()
        simulationTimer     = nil
        wireNode.removeFromParentNode()
        markedPosition      = nil
    }


// MARK: - Registry
    private func saveReg() {
        guard storeInReg.count > 0 else {
            return
        }
        for key in storeInReg {
            let v = valueForKey(key)
            setReg(key.description, value: v)
        }
        setReg(SettingsTableKey.none.description, value: "valid")
    }
    private func loadReg() {
        guard storeInReg.count > 0 else {
            return
        }
        
        // check if values are stored
        guard let _ = getReg(SettingsTableKey.none.description) else {
            return
        }
        
        for key in storeInReg {
            if let v =  getReg(key.description) {
                valueForKey(key, value: v, initial: true)
            }
        }
    }
    
    
    private func getReg(_ forKey: String?) -> String? {
        if let key = forKey {
            return UserDefaults.standard.string(forKey: key)
        } else {
            return nil
        }
    }
    func setReg(_ forKey: String?, value: String?) {
        if let key = forKey,
            let v   = value {
            return UserDefaults.standard.set(v, forKey: key)
        }
    }
    private func clearReg(_ forKey: String?) {
        if let key = forKey {
            return UserDefaults.standard.set(nil, forKey: key)
        }
    }


// MARK: - Interface
    public enum DataType: Int {
        case none
        case header
        case double
        case uint
        case boolean
        case string
      //  case color
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
        case .shapeRotationY:           return .double
        case .shapeRotationW:           return .double
        case .shapeX:                   return .double
        case .shapeY:                   return .double
        case .shapeChangeAxis:          return .boolean
        case .shapeMirrorHorizontal:    return .boolean
        case .shapeMirrorVertical:      return .boolean
        case .shapeReverse:             return .boolean
        case .preview:                  return .header
        case .showAxisGraph:            return .boolean
        case .showShapeGraph:           return .boolean
        case .showCutterGraph:          return .boolean
        case .showBlockGraph:           return .boolean
        case .showShapeCutGraph:        return .boolean
        case .simulationSpeed:          return .double
        case .previewDiameter:          return .double
        case .hotwireSettingComment:    return .string
        case .blockMaterialComment:     return .string
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
             .shapeRotationY,
             .shapeRotationW,
             .shapeX,
             .shapeY,
             .shapeChangeAxis,
             .shapeMirrorHorizontal,
             .shapeMirrorVertical,
             .shapeReverse,
             .simulationSpeed,
             .previewDiameter,
             .hotwireSettingComment,
             .blockMaterialComment:
            
            
            
                    return true
        default:    return false
        }
    }
    
    public func labelForKey(_ key: SettingsTableKey) -> String {
        switch (key) {
        case .spacer:                   return ""
        case .cutter:                   return "Machine:"
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
        case .shapeRotationY:           return "Z-Rotation around lower left corner [°]:"
        case .shapeRotationW:           return "W-Rotation around lower left corner [°]:"
        case .shapeX:                   return "X movement"
        case .shapeY:                   return "Y movement"
        case .shapeChangeAxis:          return "Change axis:"
        case .shapeMirrorHorizontal:    return "Mirror horizontal:"
        case .shapeMirrorVertical:      return "Mirror vertical:"
        case .shapeReverse:             return "Reverse shape:"
        case .preview:                  return "Preview"
        case .showAxisGraph:            return "Show machine movement:"
        case .showShapeGraph:           return "Show shape:"
        case .showCutterGraph:          return "Show machine dimension:"
        case .showBlockGraph:           return "Show foam dimensions:"
        case .showShapeCutGraph:        return "Show shape cutting line:"
        case .simulationSpeed:          return "Simulation Speed Factor:"
        case .previewDiameter:          return "Diamater of Hotwire:"
        case .hotwireSettingComment:    return "Settings (Voltage, Comment, ...):"
        case .blockMaterialComment:     return "Material (Comment, ...):"
        default:           return ""
        }
    }
    public func valueForKey(_ key: SettingsTableKey) -> String {
        switch (key) {
        case .cutterWidth:              return dtos(data.cutterWidth,            decimals: 0, true)
        case .cutterHeight:             return dtos(data.cutterHeight,           decimals: 0, true)
        case .cutterDepth:              return dtos(data.cutterDepth,            decimals: 0, true)
        case .labelX1Axis:              return data.labelX1Axis
        case .labelY1Axis:              return data.labelY1Axis
        case .labelX2Axis:              return data.labelX2Axis
        case .labelY2Axis:              return data.labelY2Axis
        case .gcodeDecimals:            return String(data.gcodeDecimals)
        case .targetFeedSpeed:          return String(data.targetFeedSpeed)
        case .maxFeedSpeed:             return String(data.maxFeedSpeed)
        case .feedSpeedCorrection:      return btos(data.feedSpeedCorrection)
        case .fastPretravel:            return btos(data.fastPretravel)
        case .pretravelSpeed:           return String(data.pretravelSpeed)
        case .hotwirePower:             return String(data.hotwirePower)
        case .hotwirePreheat:           return String(data.hotwirePreheat)
        case .blockWidth:               return dtos(data.blockWidth,             decimals: 0, true)
        case .blockHeight:              return dtos(data.blockHeight,            decimals: 0, true)
        case .blockDepth:               return dtos(data.blockDepth,             decimals: 0, true)
        case .blockSpacingLeft:         return dtos(data.blockSpacingLeft,       decimals: 0, true)
        case .blockSpacingFront:        return dtos(data.blockSpacingFront,      decimals: 0, true)
        case .blockSpacingUnder:        return dtos(data.blockSpacingUnder,      decimals: 0, true)
        case .blockRotation:            return dtos(data.blockRotation,          decimals: 0, true)
        case .shapeWidth:               return dtos(data.shapeWidth,             decimals: 0, true)
        case .shapeSpacingLeft:         return dtos(data.shapeSpacingLeft,       decimals: 0, true)
        case .shapeRotationY:           return dtos(data.shapeRotationY,         decimals: 0, true)
        case .shapeRotationW:           return dtos(data.shapeRotationW,         decimals: 0, true)
        case .shapeX:                   return dtos(data.shapeX,                 decimals: data.gcodeDecimals, true)
        case .shapeY:                   return dtos(data.shapeY,                 decimals: data.gcodeDecimals, true)
        case .shapeChangeAxis:          return btos(data.shapeChangeAxis)
        case .shapeMirrorHorizontal:    return btos(data.shapeMirrorHorizontal)
        case .shapeMirrorVertical:      return btos(data.shapeMirrorVertical)
        case .shapeReverse:             return btos(data.shapeReverse)
        case .showAxisGraph:            return btos(showAxisGraph)
        case .showShapeGraph:           return btos(showShapeGraph)
        case .showCutterGraph:          return btos(showCutterGraph)
        case .showBlockGraph:           return btos(showBlockGraph)
        case .showShapeCutGraph:        return btos(showShapeCutGraph)
        case .simulationSpeed:          return dtos(simulationSpeed,        decimals: 0, true)
        case .previewDiameter:          return dtos(previewDiameter,        decimals: 1, true)
        case .hotwireSettingComment:    return data.hotwireSettingComment
        case .blockMaterialComment:     return data.blockMaterialComment
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
        case .targetFeedSpeed:          return value.isValidUInt(0, data.maxFeedSpeed)
        case .maxFeedSpeed:             return value.isValidUInt(0)
        case .feedSpeedCorrection:      return true // ToDo ggf. prüfung auf 1 und 0
        case .fastPretravel:            return true // ToDo ggf. prüfung auf 1 und 0
        case .pretravelSpeed:           return value.isValidUInt(0)
        case .hotwirePower:             return value.isValidUInt(0, 100)
        case .hotwirePreheat:           return value.isValidUInt(0, 30)
        case .blockWidth:               return value.isValidDouble(0, 0, data.cutterWidth)
        case .blockHeight:              return value.isValidDouble(0, 0)
        case .blockDepth:               return value.isValidDouble(0, 0)
        case .blockSpacingLeft:         return value.isValidDouble(0, 0, data.cutterWidth - data.blockWidth)
        case .blockSpacingFront:        return value.isValidDouble(0, 0)
        case .blockSpacingUnder:        return value.isValidDouble(0, 0)
        case .blockRotation:            return value.isValidDouble(0, -90.0, 90.0)
        case .shapeWidth:               return value.isValidDouble(0, 0, data.cutterWidth)
        case .shapeSpacingLeft:         return value.isValidDouble(0, 0, data.cutterWidth - data.shapeWidth)
        case .shapeRotationY:           return value.isValidDouble(0, -90.0, 90.0)
        case .shapeRotationW:           return value.isValidDouble(0, -180.0, 180.0)
        case .shapeX:                   return value.isValidDouble(data.gcodeDecimals, -1000.0)
        case .shapeY:                   return value.isValidDouble(data.gcodeDecimals, -1000.0)
        case .shapeChangeAxis:          return true
        case .shapeMirrorHorizontal:    return true
        case .shapeMirrorVertical:      return true
        case .shapeReverse:             return true
        case .showAxisGraph:            return true // ToDo ggf. prüfung auf 1 und 0
        case .showShapeGraph:           return true
        case .showCutterGraph:          return true
        case .showBlockGraph:           return true
        case .showShapeCutGraph:        return true
        case .simulationSpeed:          return value.isValidDouble(1, 1,  500)
        case .previewDiameter:          return value.isValidDouble(1, 0.1,  5.0)
        case .hotwireSettingComment:    return true
        case .blockMaterialComment:     return true
        default: return false
        }
    }
    public func valueForKey(_ key: SettingsTableKey, value: String?, initial: Bool = false) {
        switch (key) {
        case .cutterWidth:              data.cutterWidth             = stod(value, true);     break;
        case .cutterHeight:             data.cutterHeight            = stod(value, true);     break;
        case .cutterDepth:              data.cutterDepth             = stod(value, true);     break;
        case .labelX1Axis:              data.labelX1Axis             = value ?? "X";          break;
        case .labelY1Axis:              data.labelY1Axis             = value ?? "Y";          break;
        case .labelX2Axis:              data.labelX2Axis             = value ?? "U";          break;
        case .labelY2Axis:              data.labelY2Axis             = value ?? "Z";          break;
        case .gcodeDecimals:            data.gcodeDecimals           = stoui(value);          break;
        case .targetFeedSpeed:          data.targetFeedSpeed         = stoui(value);          break;
        case .maxFeedSpeed:             data.maxFeedSpeed            = stoui(value);          break;
        case .feedSpeedCorrection:      data.feedSpeedCorrection     = stob(value);           break;
        case .fastPretravel:            data.fastPretravel           = stob(value);           break;
        case .pretravelSpeed:           data.pretravelSpeed          = stoui(value);          break;
        case .hotwirePower:             data.hotwirePower            = stoui(value);          break;
        case .hotwirePreheat:           data.hotwirePreheat          = stoui(value);          break;
        case .blockWidth:               data.blockWidth              = stod(value, true);     break;
        case .blockHeight:              data.blockHeight             = stod(value, true);     break;
        case .blockDepth:               data.blockDepth              = stod(value, true);     break;
        case .blockSpacingLeft:         data.blockSpacingLeft        = stod(value, true);     break;
        case .blockSpacingFront:        data.blockSpacingFront       = stod(value, true);     break;
        case .blockSpacingUnder:        data.blockSpacingUnder       = stod(value, true);     break;
        case .blockRotation:            data.blockRotation           = stod(value, true);     break;
        case .shapeWidth:               data.shapeWidth              = stod(value, true);     break;
        case .shapeSpacingLeft:         data.shapeSpacingLeft        = stod(value, true);     break;
        case .shapeRotationY:           data.shapeRotationY          = stod(value, true);     break;
        case .shapeRotationW:           data.shapeRotationW          = stod(value, true);     break;
        case .shapeX:                   data.shapeX                  = stod(value, true);     break;
        case .shapeY :                  data.shapeY                  = stod(value, true);     break;
        case .shapeChangeAxis:          data.shapeChangeAxis         = stob(value);
                                        changeAxis();
                                        break;
        case .shapeMirrorHorizontal:    data.shapeMirrorHorizontal   = stob(value);
                                        mirrorHorizontal();
                                        break;
        case .shapeMirrorVertical:      data.shapeMirrorVertical     = stob(value);
                                        mirrorVertical();
                                        break;
        case .shapeReverse:             data.shapeReverse            = stob(value);
                                        reverseShape();
                                        break;
        case .showAxisGraph:            self.showAxisGraph           = stob(value);
                                        axisNode.isHidden            = !self.showAxisGraph
                                        break
        case .showShapeGraph:           self.showShapeGraph          = stob(value);
                                        shapeNode.isHidden           = !self.showShapeGraph
                                        mergingShapeNode.isHidden    = !self.showShapeGraph
                                        break
        case .showCutterGraph:          self.showCutterGraph         = stob(value);
                                        cutterNode.isHidden          = !self.showCutterGraph
                                        break
        case .showBlockGraph:           self.showBlockGraph          = stob(value);
                                        blockNode.isHidden           = !self.showBlockGraph
                                        break
        case .showShapeCutGraph:        self.showShapeCutGraph       = stob(value);
                                        shapeCutNode.isHidden        = !self.showShapeCutGraph
                                        mergingShapeCutNode.isHidden = !self.showShapeCutGraph
                                        break
        case .simulationSpeed:          self.simulationSpeed         = stod(value, true);     break;
        case .previewDiameter:          self.previewDiameter         = stod(value, true);     break;
        case .hotwireSettingComment:    data.hotwireSettingComment   = value ?? "";           break;
        case .blockMaterialComment:     data.blockMaterialComment    = value ?? "";           break;
        default: return
        }
        
        
        if initial == true {     // skip postprocessing for new data, if it is an initial Load
            return
        }
        saveReg()
        
        switch (key) {
        case .cutterWidth,
             .cutterHeight,
             .cutterDepth,
             .shapeWidth,
             .shapeSpacingLeft,
             .shapeRotationY,
             .shapeRotationW,
             .shapeX,
             .shapeY,
             .shapeChangeAxis,
             .shapeMirrorHorizontal,
             .shapeMirrorVertical,
             .shapeReverse,
             .previewDiameter:          // neu berechnen und Graph aktualisieren
                                        _ = calculateShape()
                                        _ = generatePreview()
                                        break
        case .targetFeedSpeed,
             .maxFeedSpeed,
             .feedSpeedCorrection,
             .fastPretravel,
             .pretravelSpeed:           _ = calculateShape()    // nur neu berechnen
                                        break
            
        case .blockWidth,
             .blockHeight,
             .blockDepth,
             .blockSpacingLeft,
             .blockSpacingFront,
             .blockSpacingUnder,
             .blockRotation:            generateFoamBlockNode()
                                        break
        
        default: return
        }
    }
   
    func valueFor(_ key: PositionTableKey, index: Int) -> String? {
        if index >= data.positions.count {
            return nil
        }
        let position = data.positions[index]
        switch key {
        case .x1Axis:       return dtos(position.x1Axis,     decimals: data.gcodeDecimals, true)
        case .y1Axis:       return dtos(position.y1Axis,     decimals: data.gcodeDecimals, true)
        case .x2Axis:       return dtos(position.x2Axis,     decimals: data.gcodeDecimals, true)
        case .y2Axis:       return dtos(position.y2Axis,     decimals: data.gcodeDecimals, true)
        case .x1Shape:      return dtos(position.x1Shape,    decimals: data.gcodeDecimals, true)
        case .y1Shape:      return dtos(position.y1Shape,    decimals: data.gcodeDecimals, true)
        case .w1Shape:      return dtos(position.w1Shape,    decimals: data.gcodeDecimals, true)
        case .x2Shape:      return dtos(position.x2Shape,    decimals: data.gcodeDecimals, true)
        case .y2Shape:      return dtos(position.y2Shape,    decimals: data.gcodeDecimals, true)
        case .w2Shape:      return dtos(position.w2Shape,    decimals: data.gcodeDecimals, true)
        case .x1Block:      return dtos(position.x1Block,    decimals: data.gcodeDecimals, true)
        case .y1Block:      return dtos(position.y1Block,    decimals: data.gcodeDecimals, true)
        case .w1Block:      return dtos(position.w1Block,    decimals: data.gcodeDecimals, true)
        case .x2Block:      return dtos(position.x2Block,    decimals: data.gcodeDecimals, true)
        case .y2Block:      return dtos(position.y2Block,    decimals: data.gcodeDecimals, true)
        case .w2Block:      return dtos(position.w2Block,    decimals: data.gcodeDecimals, true)
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
            return value.isValidDouble(data.gcodeDecimals)
        case .hotwire, .pretravel:
            return true
        default: return false
        }
    }
    

    func valueFor(_ key: PositionTableKey, index: Int, value: String?) {
        if index >= data.positions.count {
            return
        }
        guard let value = value else {
            return
        }
        var key = key
        let position = data.positions[index]
        
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
        
        stop()                                      // stop the simulation
        calculatePosition(position, source: key)
        _ = calculateShape()                        // damit sind auch die Speed berechnungen aktuell
        requestUpdatePositionsTable(index)
        
        generateShapeNode(index: index)
        generateShapeCutNode(index: index)
        generateAxisNode(index: index)
        
        return
    }
    
    
    func deleteIndex(_ index: Int) {
        guard index < data.positions.count else {
            return
        }
        data.positions.remove(at: index)
        // neu berechnen und Graph aktualisieren
        _ = calculateShape()
        _ = generatePreview()
        return
    }
    func addIndex(_ index: Int) {
        guard data.positions.count > 0 else {
            return
        }
        
        var p1: CuttingPosition
        var p2: CuttingPosition
        
        if index < data.positions.count {
            p2 = data.positions[index]
        } else {
            p2 = data.positions.last!
        }
        
        if index > 0 {
            p1 = data.positions[index-1]
        } else {
            p1 = data.positions.first!
        }
        
        let p = CuttingPosition()
        p.x1Shape     =  (p2.x1Shape + p1.x1Shape) / 2
        p.y1Shape     =  (p2.y1Shape + p1.y1Shape) / 2
        p.w1Shape     =  (p2.w1Shape + p1.w1Shape) / 2
        p.x2Shape     =  (p2.x2Shape + p1.x2Shape) / 2
        p.y2Shape     =  (p2.y2Shape + p1.y2Shape) / 2
        p.w2Shape     =  (p2.w2Shape + p1.w2Shape) / 2
        
        if index < data.positions.count {
            data.positions.insert(p, at: index)
        } else {
            data.positions.append(p)
        }
        
        // neu berechnen und Graph aktualisieren
        _ = calculateShape()
        _ = generatePreview()
        return
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

